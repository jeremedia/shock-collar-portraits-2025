require "test_helper"
require "zip"

class GalleryControllerTest < ActionDispatch::IntegrationTest
  def setup
    @burn = BurnEvent.create!(theme: "OKNOTOK", year: 2025, location: "BRC")
    @day = SessionDay.create!(burn_event: @burn, day_name: "monday", date: Date.today)
    @session = PhotoSession.create!(
      session_day: @day,
      session_number: 1234,
      burst_id: "burst_1234",
      started_at: Time.current,
      ended_at: Time.current,
      photo_count: 2,
      hidden: false
    )

    @tmp_dir = Dir.mktmpdir("photos")
    @file1 = File.join(@tmp_dir, "IMG_0001.JPG")
    @file2 = File.join(@tmp_dir, "IMG_0002.JPG")
    File.write(@file1, "one")
    File.write(@file2, "two")

    Photo.create!(photo_session: @session, filename: File.basename(@file1), original_path: @file1, position: 1, rejected: false)
    Photo.create!(photo_session: @session, filename: File.basename(@file2), original_path: @file2, position: 2, rejected: false)
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && Dir.exist?(@tmp_dir)
  end

  test "download_all returns a valid zip with expected files" do
    get download_all_gallery_path(@session.burst_id)
    assert_response :success
    assert_equal "application/zip", response.media_type

    io = StringIO.new(response.body)
    entries = []
    Zip::InputStream.open(io) do |zis|
      while (entry = zis.get_next_entry)
        entries << entry.name
      end
    end

    # Filenames are prefixed with position (001_, 002_)
    assert_includes entries, "001_#{File.basename(@file1)}"
    assert_includes entries, "002_#{File.basename(@file2)}"
  end
end


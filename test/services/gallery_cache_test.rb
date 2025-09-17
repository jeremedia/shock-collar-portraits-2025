require 'test_helper'

class GalleryCacheTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear

    @burn = BurnEvent.create!(theme: 'OKNOTOK', year: 2025, location: 'BRC')
    @day = SessionDay.create!(burn_event: @burn, day_name: 'monday', date: Date.parse('2025-08-26'))

    @session_with_hero = PhotoSession.create!(
      session_day: @day,
      session_number: 1,
      burst_id: 'burst_1',
      started_at: Time.zone.parse('2025-08-26 09:00'),
      ended_at: Time.zone.parse('2025-08-26 09:30'),
      photo_count: 2,
      hidden: false
    )

    hero_photo = Photo.create!(
      photo_session: @session_with_hero,
      filename: 'hero.jpg',
      position: 1,
      rejected: false
    )
    Photo.create!(
      photo_session: @session_with_hero,
      filename: 'hero-2.jpg',
      position: 2,
      rejected: false
    )
    @session_with_hero.update!(hero_photo: hero_photo)

    @session_without_hero = PhotoSession.create!(
      session_day: @day,
      session_number: 2,
      burst_id: 'burst_2',
      started_at: Time.zone.parse('2025-08-26 10:00'),
      ended_at: Time.zone.parse('2025-08-26 10:25'),
      photo_count: 3,
      hidden: false
    )

    Photo.create!(
      photo_session: @session_without_hero,
      filename: 'shot-1.jpg',
      position: 0,
      rejected: false
    )
    @middle_photo = Photo.create!(
      photo_session: @session_without_hero,
      filename: 'shot-2.jpg',
      position: 1,
      rejected: false,
      face_data: { face_count: 1 }
    )
    Photo.create!(
      photo_session: @session_without_hero,
      filename: 'shot-3.jpg',
      position: 2,
      rejected: false
    )
  end

  test 'index payload returns expected data without hero filter' do
    version = GalleryCache.version
    payload = GalleryCache.index_payload(version:, hide_heroes: false, force: true)

    assert_equal [@session_with_hero.id, @session_without_hero.id], payload[:session_ids_by_day]['monday']
    assert_equal 2, payload[:stats][:total_sessions]
    assert_equal 5, payload[:stats][:total_photos]
    assert_equal @middle_photo.id, payload[:middle_photo_ids][@session_without_hero.id]
    assert_nil payload[:middle_photo_ids][@session_with_hero.id]
    assert_equal 1, payload[:face_counts][@session_without_hero.id]
  end

  test 'index payload filters hero sessions when requested' do
    version = GalleryCache.version
    payload = GalleryCache.index_payload(version:, hide_heroes: true, force: true)

    assert_equal [@session_without_hero.id], payload[:session_ids_by_day]['monday']
    assert_equal 1, payload[:stats][:total_sessions]
    assert_equal 3, payload[:stats][:total_photos]
    assert_equal @middle_photo.id, payload[:middle_photo_ids][@session_without_hero.id]
    assert_nil payload[:middle_photo_ids][@session_with_hero.id]
  end
end

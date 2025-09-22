class Admin::TagsController < ApplicationController
  before_action :require_admin!
  before_action :set_tag, only: [ :show, :edit, :update, :destroy, :move_up, :move_down ]

  def index
    @tags_by_category = TagDefinition::CATEGORIES.each_with_object({}) do |category, hash|
      hash[category] = TagDefinition.by_category(category).ordered
    end
  end

  def show
  end

  def new
    @tag = TagDefinition.new
  end

  def create
    @tag = TagDefinition.new(tag_params)

    if @tag.save
      redirect_to admin_tags_path, notice: "Tag was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to admin_tags_path, notice: "Tag was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy
    redirect_to admin_tags_path, notice: "Tag was successfully deleted."
  end

  def move_up
    swap_with_adjacent(:up)
  end

  def move_down
    swap_with_adjacent(:down)
  end

  def bulk_reorder
    params[:tag_ids].each_with_index do |id, index|
      TagDefinition.where(id: id).update_all(display_order: index)
    end
    head :ok
  end

  private

  def set_tag
    @tag = TagDefinition.find(params[:id])
  end

  def tag_params
    params.require(:tag_definition).permit(:name, :category, :display_name, :emoji, :display_order, :active, :color, :description)
  end

  def swap_with_adjacent(direction)
    tags_in_category = TagDefinition.by_category(@tag.category).ordered.to_a
    current_index = tags_in_category.index(@tag)

    if direction == :up && current_index > 0
      swap_tag = tags_in_category[current_index - 1]
    elsif direction == :down && current_index < tags_in_category.length - 1
      swap_tag = tags_in_category[current_index + 1]
    end

    if swap_tag
      current_order = @tag.display_order
      @tag.update(display_order: swap_tag.display_order)
      swap_tag.update(display_order: current_order)
    end

    redirect_to admin_tags_path
  end
end

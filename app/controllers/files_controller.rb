class FilesController < ApplicationController
  before_action :require_existing_file, :only => [:show, :edit, :update, :destroy, :showpdfasimage]
  before_action :require_existing_target_folder, :only => [:new, :create]

  before_action :require_create_permission, :only => [:new, :create]
  before_action :require_read_permission, :only => :show
  before_action :require_update_permission, :only => [:edit, :update]
  before_action :require_delete_permission, :only => :destroy

  # @file and @folder are set in require_existing_file
  def show
    send_file @file.attachment.path, :filename => @file.attachment_file_name
  end

  # @target_folder is set in require_existing_target_folder
  def new
    @file = @target_folder.user_files.build
  end

  # @target_folder is set in require_existing_target_folder
  def create
    @file = @target_folder.user_files.create(permitted_params.user_file)
    render :nothing => true
  end

  # @file and @folder are set in require_existing_file
  def edit
  end

  # @file and @folder are set in require_existing_file
  def update
    if @file.update_attributes(permitted_params.user_file)
      redirect_to edit_file_url(@file), :notice => t(:your_changes_were_saved)
    else
      render :action => 'edit'
    end
  end

  # @file and @folder are set in require_existing_file
  def destroy
    @file.destroy
    redirect_to @folder
  end

  def showpdfasimage
    imageslist = Magick::ImageList.new(@file.attachment.path) do
      self.density = 150
    end

    mark = Magick::Image.new(imageslist.rows, imageslist.columns) {self.background_color = "none"}
    draw = Magick::Draw.new
    draw.annotate(mark, 0, 0, 0, 0, "NÃO COPIAR") do
      draw.gravity = Magick::CenterGravity
      draw.pointsize = 150
      draw.font_family = "Times" # set font
      draw.fill = "red" # set text color
      draw.stroke = "none" # remove stroke
    end
    mark = mark.rotate(-45)
    @pdfimages = Array.new

    imageslist.each do |page|
      page.format = 'PNG'
      img = page.dissolve(mark, 0.25, 1, Magick::CenterGravity)
      img.resize_to_fit!(1200, 1200)
      pageblob = img.to_blob
      sio = Base64.encode64(pageblob)
      @pdfimages << sio
    end
  end

  def exists
    @folder = Folder.find(params[:folder])

    if (current_user.can_read @folder) || (current_user.can_write @folder)
      @file = @folder.user_files.build(:attachment_file_name => params[:name].gsub(RESTRICTED_CHARACTERS, '_'))
      render :json => !@file.valid?
    end
  end

  private

  def require_existing_file
    @file = UserFile.find(params[:id])
    @folder = @file.folder
  rescue ActiveRecord::RecordNotFound
    redirect_to Folder.root, :alert => t(:already_deleted, :type => t(:this_file))
  end
end

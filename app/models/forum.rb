# INTENT: support for hosting multiple forums on a single Discourse database
#
# This feature must be implemented such that any standard (single-forum)
# Discourse installations are not affected in any way.
#

require_dependency 'slug'

class Forum < ActiveRecord::Base
  validates_presence_of :title

  has_many :categories
  has_many :groups

  def slug
    unless slug = read_attribute(:slug)
      return '' unless title.present?
      slug = Slug.for(title).presence || "forum"
      if new_record?
        write_attribute(:slug, slug)
      else
        update_column(:slug, slug)
      end
    end

    slug
  end

  def init
    Category.create(
      name: "Uncategorized",
      slug: "uncategorized",
      color: "AB9364",
      text_color: "FFFFFF",
      user_id: -1,
      position: 0
    )

    Forum.create
  end

  def categories
    []
  end

  def topics
    []
  end

  def groups
    []
  end

  def members
    []
  end
end

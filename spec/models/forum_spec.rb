# encoding: UTF-8

require 'spec_helper'

describe Forum do

  let(:now) { Time.zone.local(2014,10,30,8,0) }

  it { should validate_presence_of :title }

  context 'slug' do

    let(:title) { "Discussion About Important Things" }
    let(:slug) { "discussion-about-important-things" }

    it "returns a Slug for a title" do
      Slug.expects(:for).with(title).returns(slug)
      Fabricate.build(:forum, title: title).slug.should == slug
    end

    it "returns 'forum' when the slug is empty (say, non-english chars)" do
      Slug.expects(:for).with(title).returns("")
      Fabricate.build(:forum, title: title).slug.should == "forum"
    end

  end

  context "an empty forum" do
    let(:forum) {
      Fabricate.build(:forum, title: "an empty forum")
    }

    it "should have no members" do
      expect(forum.members).to be_empty
    end
    it "should have no groups" do
      expect(forum.groups).to be_empty
    end
    it "should have no categories" do
      expect(forum.categories).to be_empty
    end
    it "should have no topics" do
      expect(forum.topics).to be_empty
    end
  end

  context "an initialized forum" do
    let(:forum) {
      f = Fabricate.build(:forum, title: "an empty forum")
      f.init
    }

    skip "should have a Uncategorized category" do
      expect(forum.categories.count).to eq(1)
      c = forum.categories.first
      c.name.should == "Uncategorized"
    end

    skip "should have a Welcome topic" do
      expect(forum.topics.count).to eq(1)
      t = forum.topics.first
      expect(t.title).to eq("Welcome to the New Forum forum")
    end
  end
end

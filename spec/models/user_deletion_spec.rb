require File.dirname(__FILE__) + '/../spec_helper'

describe User, "#destroy" do
  let(:user) { Factory.create(:user) }
  let(:user2) { Factory.create(:user) }
  let(:substitute_user) { DeletedUser.first }
  let(:project) do
    project = Factory.create(:valid_project)
#    Factory.create(:member, :project => project,
#                            :user => user,
#                            :roles => [Factory.build(:role)])
#    Factory.create(:member, :project => project,
#                            :user => user2,
#                            :roles => [Factory.build(:role)])
    project
  end

  let(:meeting) { Factory.create(:meeting, :project => project,
                                           :author => user2) }
  let(:participant) { Factory.create(:meeting_participant, :user => user,
                                                           :meeting => meeting,
                                                           :invited => true,
                                                           :attended => true) }

  before do
    user
    user2
  end

  shared_examples_for "updated journalized associated object" do
    before do
      User.current = user2
      associations.each do |association|
        associated_instance.send(association.to_s + "=", user2)
      end
      associated_instance.save!

      User.current = user # in order to have the content journal created by the user
      associated_instance.reload
      associations.each do |association|
        associated_instance.send(association.to_s + "=", user)
      end
      associated_instance.save!

      user.destroy
      associated_instance.reload
    end

    it { associated_class.find_by_id(associated_instance.id).should == associated_instance }
    it "should replace the user on all associations" do
      associations.each do |association|
        associated_instance.send(association).should == substitute_user
      end
    end
    it { associated_instance.journals.first.user.should == user2 }
    it "should update first journal changes" do
      associations.each do |association|
        associated_instance.journals.first.changes[association.to_s + "_id"].last.should == user2.id
      end
    end
    it { associated_instance.journals.last.user.should == substitute_user }
    it "should update second journal changes" do
      associations.each do |association|
        associated_instance.journals.last.changes[association.to_s + "_id"].last.should == substitute_user.id
      end
    end
  end

  shared_examples_for "created journalized associated object" do
    before do
      User.current = user # in order to have the content journal created by the user
      associations.each do |association|
        associated_instance.send(association.to_s + "=", user)
      end
      associated_instance.save!

      User.current = user2
      associated_instance.reload
      associations.each do |association|
        associated_instance.send(association.to_s + "=", user2)
      end
      associated_instance.save!

      user.destroy
      associated_instance.reload
    end

    it { associated_class.find_by_id(associated_instance.id).should == associated_instance }
    it "should keep the current user on all associations" do
      associations.each do |association|
        associated_instance.send(association).should == user2
      end
    end
    it { associated_instance.journals.first.user.should == substitute_user }
    it "should update the first journal" do
      associations.each do |association|
        associated_instance.journals.first.changes[association.to_s + "_id"].last.should == substitute_user.id
      end
    end
    it { associated_instance.journals.last.user.should == user2 }
    it "should update the last journal" do
      associations.each do |association|
        associated_instance.journals.last.changes[association.to_s + "_id"].first.should == substitute_user.id
        associated_instance.journals.last.changes[association.to_s + "_id"].last.should == user2.id
      end
    end
  end

  describe "WHEN the user created a meeting" do
    let(:associations) { [:author] }
    let(:associated_instance) { Factory.build(:meeting, :project => project) }
    let(:associated_class) { Meeting }

    it_should_behave_like "created journalized associated object"
  end

  describe "WHEN the user updated a meeting" do
    let(:associations) { [:author] }
    let(:associated_instance) { Factory.build(:meeting, :project => project) }
    let(:associated_class) { Meeting }

    it_should_behave_like "updated journalized associated object"
  end

  describe "WHEN the user created a meeting agenda" do
    let(:associations) { [:author] }
    let(:associated_instance) { Factory.build(:meeting_agenda, :meeting => meeting,
                                                               :text => "lorem")}
    let(:associated_class) { MeetingAgenda }

    it_should_behave_like "created journalized associated object"
  end

  describe "WHEN the user updated a meeting agenda" do
    let(:associations) { [:author] }
    let(:associated_instance) { Factory.build(:meeting_agenda, :meeting => meeting,
                                                               :text => "lorem")}
    let(:associated_class) { MeetingAgenda }

    it_should_behave_like "updated journalized associated object"
  end

  describe "WHEN the user created a meeting minutes" do
    let(:associations) { [:author] }
    let(:associated_instance) { Factory.build(:meeting_minutes, :meeting => meeting,
                                                                :text => "lorem")}
    let(:associated_class) { MeetingMinutes }

    it_should_behave_like "created journalized associated object"
  end

  describe "WHEN the user updated a meeting minutes" do
    let(:associations) { [:author] }
    let(:associated_instance) { Factory.build(:meeting_minutes, :meeting => meeting,
                                                               :text => "lorem")}
    let(:associated_class) { MeetingMinutes }

    it_should_behave_like "updated journalized associated object"
  end

  describe "WHEN the user participated in a meeting" do
    before do
      participant
      # user2 added to participants by beeing the author

      user.destroy
      meeting.reload
      participant.reload
    end

    it { meeting.participants.map(&:user).should =~ [DeletedUser.first, user2] }
    it { participant.invited.should be_true }
    it { participant.attended.should be_true }
  end
end
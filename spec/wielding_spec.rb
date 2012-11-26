require_relative 'spec_helper'

describe RedstoneBot::Wielding do
  include WindowSpecHelper

  let(:client) { @client }
  let(:bot) { @bot }
  let(:hotbar_spots) { bot.window_tracker.inventory_window.inventory.hotbar_spots }
  
  before do
    @bot = TestBot.new_at_position RedstoneBot::Coords[8, 70, 8]
    @client = @bot.client
    
    items = [nil]*45
    items[10] = RedstoneBot::ItemType::IronShovel * 1
    items[12] = RedstoneBot::ItemType::Bread * 2
    items[36] = RedstoneBot::ItemType::WheatItem * 31
    items[37] = RedstoneBot::ItemType::Bread * 44    
    server_load_window 0, items    
  end
  
  it "initially the first spot in the hotbar is wielded" do
    bot.wielded_spot.should == hotbar_spots[0]
  end
  
  it "defined wielded_item" do
    bot.wielded_item.should == RedstoneBot::ItemType::WheatItem * 31
  end
  
  describe :wield do
    shared_examples_for "it succeeds trivially" do
      it "doesn't send any packets and returns true" do
        @client.should_not_receive :send_packet
        @bot.wield(wield_spec).should == true
        @bot.wielded_spot.should == hotbar_spots[0]
        @bot.window_tracker.should be_synced
      end    
    end

    shared_examples_for "it switches to the second hotbar spot" do
      it "can hold another item in the hotbar with a single packet" do
        @client.should_receive(:send_packet).with(RedstoneBot::Packet::HeldItemChange.new(1))
        @bot.wield(wield_spec).should == true
        @bot.wielded_spot.should == hotbar_spots[1]
        @bot.window_tracker.should be_synced
      end
    end
    
    context "when passed the currently wielded spot" do
      let(:wield_spec) { hotbar_spots[0] }
      it_behaves_like "it succeeds trivially"
    end
    
    context "when passed the currently wielded exact item" do
      let(:wield_spec) { RedstoneBot::ItemType::WheatItem * 31 }
      it_behaves_like "it succeeds trivially"      
    end

    context "when passed the currently wielded item type" do
      let(:wield_spec) { RedstoneBot::ItemType::WheatItem }
      it_behaves_like "it succeeds trivially"
    end
    
    context "when passed another spot in the hotbar" do
      let(:wield_spec) { hotbar_spots[1] }
      it_behaves_like "it switches to the second hotbar spot"
    end    
  end
  
end
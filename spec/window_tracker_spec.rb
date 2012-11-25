require_relative 'spec_helper'
require 'redstone_bot/trackers/window_tracker'

shared_examples_for 'uses SpotArray for' do |*array_names|
  array_names.each do |array_name|
    it array_name.to_s do
      subject.send(array_name).should be_a RedstoneBot::SpotArray
    end
  end
end

describe RedstoneBot::WindowTracker::Inventory do
  it "has general purpose spots" do
    subject.should have(36).regular_spots
  end  

  it "has 9 hotbar spots" do
    subject.should have(9).hotbar_spots
  end
  
  it "has hotbar spots at the end of the regular spots array" do
    # This is required for the slot ids in the InventoryWindow and ChestWindow to be correct
    subject.hotbar_spots.should == subject.regular_spots[-9,9]
  end

  it "has four spots for armor" do
    subject.armor_spots.should == [subject.helmet_spot, subject.chestplate_spot, subject.leggings_spot, subject.boots_spot]
  end
  
  it "has easy access to all the spots" do
    subject.spots.should == subject.armor_spots + subject.regular_spots
  end
  
  it "has no duplicate spots" do
    subject.spots.uniq.should == subject.spots
  end
    
  it "initially has empty spots" do
    subject.spots.each do |spot|
      spot.should be_a RedstoneBot::Spot
      spot.should be_empty
    end
  end
  
  it_has_behavior 'uses SpotArray for', :armor_spots, :regular_spots, :hotbar_spots, :spots
end

describe RedstoneBot::WindowTracker::InventoryCrafting do
  it "has four input spots" do
    subject.input_spots.should == [subject.upper_left, subject.upper_right, subject.lower_left, subject.lower_right]
  end
  
  it "can fetch input slots by row,column" do
    subject.input_spot(0, 0).should == subject.upper_left
    subject.input_spot(0, 1).should == subject.upper_right
    subject.input_spot(1, 0).should == subject.lower_left
    subject.input_spot(1, 1).should == subject.lower_right
  end
  
  it "has an output spot" do
    subject.output_spot.should be
  end
  
  it "has easy access to all the spots" do
    subject.spots.should == [subject.output_spot] + subject.input_spots
  end
  
  it "has no duplicate spots" do
    subject.spots.uniq.should == subject.spots
  end
  
  it_has_behavior 'uses SpotArray for', :input_spots, :spots
end

describe RedstoneBot::WindowTracker::Window do
  it "complains if it doesn't recognize the window type" do
    lambda { RedstoneBot::WindowTracker::Window.create(66, nil) }.should raise_error "Unrecognized type of RedstoneBot::WindowTracker::Window: 66"
  end
end

describe RedstoneBot::WindowTracker::InventoryWindow do
  let(:inventory) { subject.inventory }
  let(:crafting) { subject.crafting }
  let(:spots) { subject.spots }
  
  it "combines inventory and inventory crafting in the proper order" do
    spots.should == crafting.spots + inventory.armor_spots +
      (inventory.regular_spots - inventory.hotbar_spots) + inventory.hotbar_spots
  end

  it "has the right spot ids" do
    # This matches http://www.wiki.vg/File:Inventory-slots.png
    spots[0].should == crafting.output_spot
    spots[1].should == crafting.upper_left
    spots[2].should == crafting.upper_right
    spots[3].should == crafting.lower_left
    spots[4].should == crafting.lower_right
    spots[5].should == inventory.helmet_spot
    spots[6].should == inventory.chestplate_spot
    spots[7].should == inventory.leggings_spot
    spots[8].should == inventory.boots_spot
    spots[9..35].should == inventory.regular_spots - inventory.hotbar_spots
    spots[36..44].should == inventory.hotbar_spots
  end
end

describe RedstoneBot::WindowTracker::ChestWindow do
  let(:inventory) { RedstoneBot::WindowTracker::Inventory.new }

  context "small chest" do
    subject { described_class.new(4, 27, inventory) }
    
    it "has 27 chest spots" do
      subject.should have(27).chest_spots
    end
    
    it "has 36 spots from the player's inventory" do
      subject.should have(36).inventory_spots
      subject.inventory_spots.should == inventory.regular_spots
    end
    
    it "has 63 total spots" do
      subject.should have(63).spots
    end
    
    it "has the right spot ids" do
      # http://www.wiki.vg/Inventory#Chest
      subject.spots[0..26].should == subject.chest_spots
      subject.spots[27..53].should == inventory.regular_spots - inventory.hotbar_spots
      subject.spots[54..62].should == inventory.hotbar_spots
    end
    
    it "can tell you the spot id of each spot" do
      subject.spot_id(subject.chest_spots[5]).should == 5
      subject.spot_id(inventory.regular_spots[3]).should == 27 + 3
      subject.spot_id(inventory.regular_spots[35]).should == 62
    end
    
    it_has_behavior 'uses SpotArray for', :chest_spots, :inventory_spots, :spots
  end
  
  context "large chest" do
    subject { described_class.new(4, 54, inventory) }
    
    it "has 54 chest spots" do
      subject.should have(54).chest_spots
    end
  end
end

describe RedstoneBot::WindowTracker do
  let(:client) { TestClient.new }
  subject { RedstoneBot::WindowTracker.new(client) }

  # Helper function to simulate an event happening from the server side.
  def server_open_window(*args)
    subject << RedstoneBot::Packet::OpenWindow.create(*args)
  end

  def server_load_window(window_id, items)
    subject << RedstoneBot::Packet::SetWindowItems.create(window_id, items)
    items.each_with_index do |item, spot_id|
      subject << RedstoneBot::Packet::SetSlot.create(window_id, spot_id, item) if item
    end    
  end
  
  def server_close_window(window_id=nil)
    subject << RedstoneBot::Packet::CloseWindow.create(subject.windows[1].id)
  end
  
  def server_transaction_decision(confirm)
    window_id = subject.usable_window.id
    transaction_id = subject.instance_variable_get(:@pending_actions).first
    subject << RedstoneBot::Packet::ConfirmTransaction.new(window_id, transaction_id, confirm)
  end

  def server_confirm_transaction
    server_transaction_decision true
  end
  
  def server_reject_transaction
    server_transaction_decision false
  end
      
  shared_examples_for "no windows are open" do
    it "has no chest model" do
      subject.chest_spots.should_not be
    end
  
    it "has just one open window (inventory)" do
      subject.should have(1).windows
    end
  end

  
  it "ignores random other packets" do
    subject << RedstoneBot::Packet::KeepAlive.new
  end
  
  context "initially" do
    it_behaves_like "no windows are open"
    
    it "has an inventory window" do
      subject.inventory_window.should be_a RedstoneBot::WindowTracker::InventoryWindow
    end
    
    it "has a nil inventory" do
      subject.inventory.should be_nil
    end
    
    it "has no usable window" do
      subject.usable_window.should be_nil
    end
  end

  context "loading an empty inventory" do
    it "is done after the SetWindowItems packet" do
      subject << RedstoneBot::Packet::SetWindowItems.create(0, [nil]*45)
      subject.inventory.should be
      subject.usable_window.should == subject.inventory_window
    end
  end
  
  context "loading a non-empty inventory" do
    let (:items) do
      [nil]*43 + [ RedstoneBot::ItemType::Melon * 2, RedstoneBot::ItemType::MushroomSoup * 2 ]
    end
    
    it "is done after all the SetSlot packets have been received" do
      inventory_window = subject.inventory_window
    
      subject << RedstoneBot::Packet::SetWindowItems.create(0, items)
      subject.inventory.should_not be
      subject << RedstoneBot::Packet::SetSlot.create(0, 43, RedstoneBot::ItemType::Melon * 2)
      subject.inventory.should_not be
      subject << RedstoneBot::Packet::SetSlot.create(0, 44, RedstoneBot::ItemType::MushroomSoup * 2)
      inventory_window.instance_variable_get(:@awaiting_set_spots).should == []
      inventory_window.should be_loaded
      subject.inventory.should be
      subject.usable_window.should == subject.inventory_window
    end
  end
  
  context "after a OpenWindow packet for a chest is received" do
    let(:window_id) { 2 }
    
    before do
      subject << RedstoneBot::Packet::OpenWindow.create(window_id, 0, "container.chest", 27)
    end

    it "has an open ChestWindow" do
      subject.windows[1].should be_a RedstoneBot::WindowTracker::ChestWindow
    end
    
    it "has an open ChestWindow with 27 chest_spots" do
      subject.windows[1].should have(27).chest_spots
    end
    
    it "doesn't have a chest model yet" do
      subject.chest_spots.should == nil
    end
    
    it "has no usable window (waiting for chest to load)" do
      subject.usable_window.should be_nil
    end
  end
  
  context "after a double chest is loaded" do
    let(:window_id) { 2 }
    let(:items) do
      chest = [RedstoneBot::ItemType::Stick*64] + [nil]*52 + [RedstoneBot::ItemType::WoodenPlanks*64]
      inventory = [nil]*36
      chest + inventory
    end
    
    before do
      server_open_window window_id, 0, "container.chestDouble", 54
      server_load_window window_id, items
    end
    
    it "has a chest model with 54 spots" do
      subject.should have(54).chest_spots
    end
    
    it "has a usuable window" do
      subject.usable_window.should be_a RedstoneBot::WindowTracker::ChestWindow
    end
    
  end
  
  it "responds to SetSlot packets for the cursor" do
    subject << RedstoneBot::Packet::SetSlot.create(-1, -1, RedstoneBot::ItemType::RedstoneRepeater * 10)
    subject.cursor_spot.item.should == RedstoneBot::ItemType::RedstoneRepeater * 10
  end
  
  context "after the inventory and a double chest is loaded" do
    let(:window_id) { 7 }
    let(:chest_items) do
      [RedstoneBot::ItemType::Flint*30, RedstoneBot::ItemType::Flint*16] +
      [nil]*51 +
      [RedstoneBot::ItemType::Netherrack*64]
    end
    let (:initial_inventory) do
      inventory = RedstoneBot::WindowTracker::Inventory.new
      inventory.hotbar_spots[0].item = RedstoneBot::ItemType::IronSword * 1
      inventory
    end
    let(:crafting_items) do
      [nil]*5
    end
    
    before do
      server_load_window 0, crafting_items + initial_inventory.spots.items      
      server_open_window window_id, 0, "container.chestDouble", 54      
      server_load_window window_id, chest_items + initial_inventory.regular_spots.items
    end
    
    it "has a chest model with 54 spots" do
      subject.should have(54).chest_spots
    end
    
    it "has no item on the cursor" do
      subject.cursor_spot.should be_empty
    end
    
    context "after left clicking on a empty spot in the chest" do
      let (:spot) { subject.chest_spots.empty_spots.first }
      before do
        subject.left_click(spot)
      end
      
      it "the spot is still empty" do
        spot.should be_empty
      end
      
      it "the cursor is still empty" do
        subject.cursor_spot.should be_empty
      end
      
      it "is be synced because no clicks happened" do
        subject.should be_synced
      end
    end
    
    context "after left clicking on 30 Flint in the chest" do
      let(:spot) { subject.chest_spots[0] }
      before do
        subject.left_click(spot)
      end
      
      it "sent the correct ClickWindow packet" do
        packet = client.sent_packets.last
        packet.should be_a RedstoneBot::Packet::ClickWindow
        packet.slot_id.should == 0
        packet.mouse_button.should == :left
        packet.shift.should == false
        packet.clicked_item.should == RedstoneBot::ItemType::Flint*30
      end
      
      it "the spot is empty" do
        spot.should be_empty
      end
      
      it "the cursor has 30 Flint" do
        subject.cursor_spot.item.should == RedstoneBot::ItemType::Flint*30
      end
      
      it { should_not be_synced }
      
      context "after confirming the transaction" do
        before do
          server_confirm_transaction
        end
        
        it { should be_synced }
      end
    end
    
    context "after swapping the items in two spots" do
      let(:spot1) { subject.inventory.hotbar_spots[0] }
      let(:spot2) { subject.chest_spots[0] }
      
      before do 
        subject.swap spot1, spot2
      end
      
      it "has swapped them" do
        subject.inventory.hotbar_spots[0].item.should == RedstoneBot::ItemType::Flint*30
        subject.chest_spots[0].item.should == RedstoneBot::ItemType::IronSword * 1
      end
    end
    
    context "and closed by the server" do
      before do
        server_close_window
      end
      
      it_behaves_like "no windows are open"
    end
    
  end

end
require 'rspec'
require_relative 'decider'
require_relative 'scenarios'

#TODO: Write a test of the tie-breaking functionality
#TODO: Write a test of :invalid token
#TODO: Write a test of the :unranked token

describe "Tests related to the :unranked and :invalid symbols" do

  before :each do
      @issue = Issue.new(:determine_capitol, ['Memphis','Nashville','Chattanooga','Knoxville'])
      @voter1 = Voter.new('People of Memphis',Ballot.new(@issue,['Memphis','Nashville','Chattanooga']),0.42)
      @voters = [@voter1]
      @tennessee = Electorate.new(@issue,@voters)
      @bush = Decider.new
  end

  it "should add an :unranked symbol to the end of the ballot where necessary" do
  validated_voters = @bush.validate_ballots(@tennessee)
  validated_voters[@voter1].last.should == :unranked
  end

end

describe "Top and bottom grabbing method tests" do

  class DummyDecider
    include VoteProcessing
  end

  rumsfeld = DummyDecider.new
  known_knowns = {'Write Zen koans' => 0.51, 'Invade Iraq' => 0.49}
  known_unknowns = {'Ignore advice' => 0.5, 'Disregard advice' => 0.5}


  it "should grab the top one choice if there is no tie" do
    rumsfeld.top_choices(known_knowns,1).should == ['Write Zen koans']
  end

  it "should grab the bottom one choice if there is no tie" do
    rumsfeld.bottom_choices(known_knowns,1).should == ['Invade Iraq']
  end

  it "should grab the top two choices if there is no tie" do
    rumsfeld.top_choices(known_knowns,2).should == ['Write Zen koans', 'Invade Iraq']
  end

  it "should grab the bottom two choices if there is no tie" do
    rumsfeld.bottom_choices(known_knowns,2).should == ['Write Zen koans', 'Invade Iraq']
  end

  it "should indicate when grabbing the top one choice results in a tie" do
    rumsfeld.top_choices(known_unknowns,1,:return_if_tie).should == :tie
  end

  it "should indicate when grabbing the bottom one choice results in a tie" do
    rumsfeld.bottom_choices(known_unknowns,1,:return_if_tie).should == :tie
  end

  it "should grab the top two choices even when those two choices are tied" do
    rumsfeld.top_choices(known_unknowns,2).should == ['Ignore advice','Disregard advice']
  end

  it "should grab the bottom two choices even when those two choices are tied" do
    rumsfeld.bottom_choices(known_unknowns,2).should == ['Ignore advice','Disregard advice']
  end

  #TODO: Test to make sure the output is always in the expected order.
  #TODO: Test to make sure grabbing zero works properly
  #TODO: Test to make sure grabbing more than the size of the hash works properly.
  #TODO: Test if it works when grabbing the top or bottom three, two of which are tied, or top four with two tied in the middle

end


describe "Nashville example, voting system tests where a Condorcet winner exists" do

  before :each do
    $logger.level = Logger::ERROR
    @issue = Issue.new(:determine_capitol, ['Memphis','Nashville','Chattanooga','Knoxville'])
    @voter1 = Voter.new('People of Memphis',Ballot.new(@issue,['Memphis','Nashville','Chattanooga','Knoxville']),0.42)
    @voter2 = Voter.new('People of Nashville',Ballot.new(@issue,['Nashville','Chattanooga','Knoxville','Memphis']),0.26)
    @voter3 = Voter.new('People of Chattanooga',Ballot.new(@issue,['Chattanooga','Knoxville','Nashville','Memphis']),0.15)
    @voter4 = Voter.new('People of Knoxville',Ballot.new(@issue,['Knoxville','Chattanooga','Nashville','Memphis']),0.17)
    @voters = [@voter1,@voter2,@voter3,@voter4]
    @tennessee = Electorate.new(@issue,@voters)
    @bush = Decider.new
  end

  after :each do
    @issue.reset_options
    $logger.level = Logger::DEBUG
  end

  it "should declare Memphis the winner using the plurality method" do
    outcome = @bush.activate_decider(@tennessee)
    outcome[0].should == "Memphis"
  end

  it "should correctly compute the voting summary using the plurality method" do
    outcome = @bush.activate_decider(@tennessee)
    outcome[1].should == {"Chattanooga" => 0.15, "Memphis" => 0.42, "Knoxville" => 0.17, "Nashville" => 0.26}
  end

  it "should declare Nashville the winner using the two-round method" do
    @tennessee.voting_system = :two_round
    outcome = @bush.activate_decider(@tennessee)
    outcome[0].should == "Nashville"
  end

  it "should correctly compute the voting summary using the two-round method" do
    @tennessee.voting_system = :two_round
    outcome = @bush.activate_decider(@tennessee)
    outcome[1].should == {"Memphis" => 0.42, "Nashville" => 0.58}
  end

  it "should declare Knoxville the winner using the exhaustive ballot method" do
    @tennessee.voting_system = :exhaustive_ballot
    outcome = @bush.activate_decider(@tennessee)
    outcome[0].should == 'Knoxville'
  end

  it "should correctly compute the voting summary using the exhaustive ballot method" do
    @tennessee.voting_system = :exhaustive_ballot
    outcome = @bush.activate_decider(@tennessee)
    outcome[1].should == {"Memphis" => 0.42, "Knoxville" =>0.58}
  end

  it "should declare Nashville the winner using the condorcet method" do
    @tennessee.voting_system = :condorcet
    outcome = @bush.activate_decider(@tennessee)
    outcome[0].should == 'Nashville'
  end

  it "should correctly compute the score of Nashville using the Kemeny-Young method" do
    @tennessee.voting_system = :kemeny_young
    outcome = @bush.activate_decider(@tennessee)
    top_ranking = outcome[0]
    ranking_scores = outcome[1]
    ranking_scores[top_ranking].should == 3.93
  end

 # it "should do something with the Ranked Pairs method" do
 #   @tennessee.voting_system = :ranked_pairs
 #   outcome = @bush.activate_decider(@tennessee)
 #   outcome.should == "Something"
 # end


end

#TODO: Write a test where there is a matchup for which none of the voters have ranked either candidate

describe "Scenario for which there is no Condorcet winner, and for which the Kemeny-Young method produces a tie" do
  before :each do
    $logger.level = Logger::ERROR
    @issue = Issue.new(:determine_favorite_letter, ['A','B','C','D','E'])
    @voter1 = Voter.new('People of AECDB',Ballot.new(@issue,['A','E','C','D','B']),0.31)
    @voter2 = Voter.new('People of BAE',Ballot.new(@issue,['B','A','E']),0.30)
    @voter3 = Voter.new('People of CDB',Ballot.new(@issue,['C','D','B']),0.29)
    @voter4 = Voter.new('People of DAE',Ballot.new(@issue,['D','A','E']),0.10)
    @voters = [@voter1,@voter2,@voter3,@voter4]
    @letterville = Electorate.new(@issue,@voters)
    @bush = Decider.new
  end

  after :each do
    @issue.reset_options
    $logger.level = Logger::DEBUG
  end

  it "should declare that there is no Condorcet winner" do
    @letterville.voting_system = :condorcet
    outcome = @bush.activate_decider(@letterville)
    outcome[0].should == :no_condor
  end

  it "should declare A the Copeland winner" do
    @letterville.voting_system = :copeland
    outcome = @bush.activate_decider(@letterville)
    p outcome
    outcome[0].should == 'A'
  end

  it "should determine that a tie has occurred with the Kemeny-Young method" do
    @letterville.voting_system = :kemeny_young
    outcome = @bush.activate_decider(@letterville)
    outcome[0].should == :tie
  end

end

describe "Scenario for which there is no Condorcet winner, and for which the Kemeny-Young and Copeland methods produce ties" do
  before :each do
    $logger.level = Logger::ERROR
    @issue = Issue.new(:determine_favorite_letter, ['A', 'B', 'C', 'D'])
    @voter1 = Voter.new('People of ACBD', Ballot.new(@issue,['A','C','B','D']),3)
    @voter2 = Voter.new('People of ACDB', Ballot.new(@issue,['A','C','D','B']),8)
    @voter3 = Voter.new('People of BACD', Ballot.new(@issue,['B','A','C','D']),3)
    @voter4 = Voter.new('People of CBDA', Ballot.new(@issue,['C','B','D','A']),6)
    @voter5 = Voter.new('People of DBAC', Ballot.new(@issue,['D','B','A','C']),6)
    @voter6 = Voter.new('People of DBCA', Ballot.new(@issue,['D','B','C','A']),4)
    @voters = [@voter1,@voter2,@voter3,@voter4,@voter5,@voter6]
    @letterville = Electorate.new(@issue,@voters)
    @bush = Decider.new
  end

  after :each do
      $logger.level = Logger::DEBUG
    end

  it "should declare that there is no Condorcet winner" do
    @letterville.voting_system = :condorcet
    outcome = @bush.activate_decider(@letterville)
    outcome[0].should == :no_condor
  end

  it "should determine that there is a tie using the Kemeny-Young method" do
    @letterville.voting_system = :kemeny_young
    outcome = @bush.activate_decider(@letterville)
    outcome[0].should == :tie
  end

  it "should determine that there is a tie using the Copeland method" do
    @letterville.voting_system = :copeland
    outcome = @bush.activate_decider(@letterville)
    outcome[0].should == :tie
  end

end




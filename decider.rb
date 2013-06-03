=begin

Author: Adam McCann

This program takes voters with ordered preferences on an issue, and for a given voting system, will compute the
winner or winners according to that system, if they exist, or identify the lack of a winner otherwise.

The following scenario, found on several Wikipedia pages describing voting systems, will be used for much of the
testing:

  Imagine the population of Tennessee is voting on the location of its capital.  Suppose the voting population
  is concentrated in its four major cities, and that all voters would like the capital to be established as close to
  their own city as possible.

issue = Issue.new(:determine_capitol, ['Memphis','Nashville','Chattanooga','Knoxville'])
voter1 = Voter.new('People of Memphis',Ballot.new(issue,['Memphis','Nashville','Chattanooga','Knoxville']),0.42)
voter2 = Voter.new('People of Nashville',Ballot.new(issue,['Nashville','Chattanooga','Knoxville','Memphis']),0.26)
voter3 = Voter.new('People of Chattanooga',Ballot.new(issue,['Chattanooga','Knoxville','Nashville','Memphis']),0.15)
voter4 = Voter.new('People of Knoxville',Ballot.new(issue,['Knoxville','Chattanooga','Nashville','Memphis']),0.17)
voters = [voter1,voter2,voter3,voter4]
tennessee = Electorate.new(issue,voters)

In the code to follow, some arbitrary variable naming conventions are followed.  For example, the word 'choice' will
refer to the individual elements of a ranked ballot, in the absence of a weighting factor;  A 'preference' will be an
Array or a Hash consisting of a choice paired with a weighting factor;  A 'voter' can be interpreted as an individual
in a group with the same vote weighting as all (i.e 1), or an individual in a group with an unequal distribution of
voting weights, or as a summary of how either of the above two types of groups voted with normalized weightings.

Thanks to Loïc Chollier for his implementation of the Floyd-Warshall algorithm.


=end

#TODO: (Documentation) Change documentation to conform to TomDoc standard. [Filler, 5]
#TODO: (Documentation) Ensure that variable names that use the word 'choice' or 'preference' are doing so correctly given the difference [3]
# preference includes a weight, whereas a choice does not.

#TODO: Write the summarize ballots function
#TODO: Check if data conversation (hash of hashes to array of hashes, things like that) can be methodized to avoid code duplication

require 'logger'
require 'benchmark'
include Math

class Hash
  def rename_key(old,new)
    self[new] = self.delete(old)
  end
end

class Array
  def is_a_set?
    self.uniq.size == self.size ? true : false
  end
end

$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG

def with_logging(description)
  $logger.debug("Starting #{ description }")
  return_value = yield
  $logger.debug("Completed #{ description }")
  return_value
end

def log_before(description)
  $logger.debug("Starting #{ description }")
  return_value = yield
end

def log_after(description)
  return_value = yield
  $logger.debug("Completed #{ description }")
  return_value
end

module VoteProcessing

  def self.build_electorate(options, total_votes)

    issue = Issue.new('issue name', options)
    voters = []
    electorate = Electorate.new(issue, voters)
    electorate.total_votes = total_votes
    yield electorate
    electorate
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end

  def self.logger= new_logger
    @logger = new_logger
  end

  def logger
    VoteProcessing.logger
  end

  #VoteProcessing.logger = my_logger

def summarize_ballots(ballots)

   summarized_ballots = ballots.inject(Hash.new(0)) do  |result, ballot|
     result[ballot.choices] += 1
     result
   end




  #TODO: (Refactor) Move the code that adds the :unranked symbol from the validate_ballots method below, to this one. [3]

  #TODO: (Ballot Validation, Errors) Create error types Unranked_Candidate_Error, Equal_Rankings_Not_Allowed_Error  [2]

  #If one or more unranked choices appear on a ballot, options are to throw an error, consider it spoiled, weight as zero,
  #or rank it / them last.  Ranking 'them' last is only possible if the voting system allows equally ranked choices.

  #There should be an option somewhere set the desired response.  Should it be in the Decider?

  #The presence of an :unranked token means, weight as zero.  So if weights are A = 0.3, B = 0.6, and C = :unranked,
  #then the total for that paired battle is 0.9, not 1.0.  If there is no :unranked token, then the system should
  #put in the actual name of the unranked choice on the ballot, or an array of the equally unranked choices.

end

# validate_ballots
#
#
# Input:  Electorate
# Output: { Voter => [String, ... , String], ... , Voter => [String, ... , String] }
#
# Description: Iterates through each Voter's ranked choices on an issue (as stated on their Ballot), discarding any invalid
#              choices. Validity is determined by comparing against the Issue's 'temp_choices' variable, not the
#              'choices' variable which is set during initialization.  The 'temp_choices' variable is used when
#              a multi-round voting system eliminates one or more choices from contention.  Thus this function can be
#              used to filter subsequent rounds' calculations as some preferences become ineligible.


  def validate_ballots(electorate)

    voters, issue = electorate.voters, electorate.issue
    validated_voters = { }

    voters.each do |voter|

      log_after("validation of #{ voter.voter_name }'s preferences") do

      validated_choices = []

      number_of_unranked = (issue.options - voter.ballot.choices).size

      if number_of_unranked > 0
        number_of_unranked.times do
          voter.ballot.choices << :unranked
        end
      end

      voter.ballot.choices.each do |choice|

        if issue.temp_options.include?(choice) || choice == :unranked
          validated_choices << choice
        else
          $logger.debug("   discarded #{ choice }")
        end
      end

      validated_voters.store(voter,validated_choices)
      end
    end

    validated_voters
  end

# grab_first_choices
#
#
# Input:  { Voter => [String, ... , String], ... , Voter => [String, ... , String] }
# Output: [ [String, Float], ... , [String, Float] ]
#
# Description: Takes a Hash of Voter keys and validated, descending-ordered preferences.  Outputs each voter's first
#              preference and their corresponding vote-weighting factor.  Given that no other function described herein
#              does such ordering, the implied assumption (here made explicit) is that the data must be in the proper
#              order to begin with.

  def grab_first_choices(validated_voters)

    first_choices = []

    validated_voters.each do |voter, validated_choices|
        first_choices << [validated_choices.first, voter.weight]
    end

    $logger.debug("\n\nFirst choices selected: #{ first_choices }\n")

    first_choices
  end

# summarize_results
#
#
# Input:   [ [String, Float], ... , [String, Float] ]
# Output:  { String => Float, ... , String => Float }
#
# Description: Summarizes the voting results of an array of [preference,weight] pairs, rounding to 2 digits.

  def summarize_results(first_choices)

    voting_summary = first_choices.reduce(Hash.new(0)) { |result, preference| result[preference.first] += preference.last; result }

    voting_summary.each do |preference, weight|
      voting_summary[preference] = weight.round(@sig_figs)
    end

    $logger.debug("\n\nResults summarized:#{ voting_summary }\n")

    voting_summary
  end

# top_choices
#
# Input:  { String => Float, ... , String => Float }, Fixnum
# Output: [ String, ... , String ]
#
# Description: Returns the top 'n' preferences from the voting summary, for some Fixnum 'n'.

#TODO: (Scenario Resolution) top_choices should return whether it was a 2-way tie, 3-way tie, etc. [9]

 # Ties should be handled in one of four ways:  It should throw an error, or auto-break the tie, or return a :tie.
 # Or, run the whole scenario with the tie broken each way to see if it affects the overall result.
 # The voting methods calling this method should be able to determine when a tie affects the overall outcome, and when it doesn't.

 # There should be an option somewhere to set the desired response.  In the Decider object?

 # Some voting systems may end up providing as input an array unnecessarily inside another array.  Rather than handle
 # that here, the voting systems themselves should be designed so that it doesn't happen.

  def top_choices(voting_summary, number, tie_handling = :break_randomly)

    num_choices = voting_summary.keys.size
    if num_choices < number then raise ArgumentError.new("Can't grab top #{number} out of #{num_choices}") end
    if number == nil || number == 0 then raise ArgumentError.new('You have to try and grab something') end

    top_n_choices, duplicates, trashbin_of_unfortunateness = [], [], []

    ordered_weights = voting_summary.values.sort.reverse
    top_n_weights = ordered_weights.first(number)
    possible_ties = voting_summary.reduce(Hash.new(0)) { |result, element| result[element] += 1; result }

    voting_summary.each_pair do |choice, weight|
      if top_n_weights.include?(weight)
        top_n_choices << choice
        duplicates << choice unless possible_ties[weight] == 1
      end
    end

    unless top_n_choices.size == number
      if tie_handling == :break_randomly
        number_to_remove = top_n_choices.size - number

        $logger.debug("To break a tie, #{ number_to_remove } will be randomly removed from among #{ duplicates }")

        number_to_remove.times { trashbin_of_unfortunateness << duplicates.delete_at(rand(duplicates.size)) }

        $logger.debug("Goodbye, #{ trashbin_of_unfortunateness }")

        top_n_choices -= trashbin_of_unfortunateness
      elsif tie_handling == :raise_error
        raise RuntimeError.new('This tie will not be tolerated.')
      elsif tie_handling == :return_if_tie
        top_n_choices = :tie
      end
    end

    top_n_choices
  end



# bottom_choices
#
# Input:  { String => Float, ... , String => Float }, Fixnum
# Output: [ String, ... , String ]
#
# Description: Returns the bottom 'n' preferences from the voting summary, for some Fixnum 'n'.

  def bottom_choices(voting_summary, number, tie_handling = :break_randomly)

    num_choices = voting_summary.keys.size
    if num_choices < number then raise ArgumentError.new("Can't grab bottom #{number} out of #{num_choices}") end
    if number == nil || number == 0 then raise ArgumentError.new('You have to try and grab something') end

    bottom_n_choices, duplicates, trashbin_of_unfortunateness = [], [], []

    ordered_weights = voting_summary.values.sort
    bottom_n_weights = ordered_weights.first(number)
    possible_ties = voting_summary.reduce(Hash.new(0)) { |result, element| result[element] += 1; result }

    voting_summary.each_pair do |choice, weight|
      if bottom_n_weights.include?(weight)
        bottom_n_choices << choice
        duplicates << choice unless possible_ties[weight] == 1
      end
    end

    unless bottom_n_choices.size == number
      if tie_handling == :break_randomly
        number_to_remove = bottom_n_choices.size - number

        $logger.debug("To break a tie, #{ number_to_remove } will be randomly removed from among #{ duplicates }")

        number_to_remove.times { trashbin_of_unfortunateness << duplicates.delete_at(rand(duplicates.size)) }

        $logger.debug("Goodbye, #{ trashbin_of_unfortunateness }")

        bottom_n_choices -= trashbin_of_unfortunateness
      elsif tie_handling == :raise_error
        raise RuntimeError.new('This tie will not be tolerated.')
      elsif tie_handling == :return_if_tie
        bottom_n_choices = :tie
      end
    end

    bottom_n_choices
  end

  def plurality_decider(electorate)
    validated_electorate = validate_ballots(electorate)
    first_choices = grab_first_choices(validated_electorate)
    voting_summary = summarize_results(first_choices)
    possible_winner = top_choices(voting_summary, 1)[0]
    outcome = [possible_winner, voting_summary]
  end

  def majority_winner?(outcome)
    possible_winner, voting_summary = outcome[0], outcome[1]

    $logger.debug("\nChecking if #{ possible_winner } has a majority")

    if voting_summary[possible_winner] > 0.5
      $logger.debug("...Yes! #{ possible_winner } has a majority!")
      true
    else
      $logger.debug("...nope.")
      false
    end
  end

  def two_round_decider(electorate)
    first_outcome = plurality_decider(electorate)
    voting_summary = first_outcome[1]
    if majority_winner?(first_outcome)
      first_outcome
    else
      top_two_choices = top_choices(voting_summary, 2)
      electorate.issue.temp_options = top_two_choices
      second_outcome = plurality_decider(electorate)
    end
  end

  def exhaustive_ballot_decider(electorate)
    first_outcome = plurality_decider(electorate)
    if majority_winner?(first_outcome)
      first_outcome
    else
      voting_summary = first_outcome[1]
      weakest_choice = bottom_choices(voting_summary, 1)
      electorate.issue.temp_options -= weakest_choice
      nth_outcome = exhaustive_ballot_decider(electorate)
    end
  end

  #condorcet_decider
  #
  # Input: Electorate
  # Output: [ String, [String, { String => Float, String => Float}], ... , [String, {String => Float, String => Float}] ]
  #
  # Description:  Calculates the Condorcet winner.

  def condorcet_decider(electorate)

    matchup_table, victory_table, matchup_winners, definite_losers = [], [], [], []

    duplicate_choices = electorate.issue.options

    $logger.debug("Generating matchup table")

    electorate.issue.options.each do |x_choice|
      duplicate_choices -= [x_choice]
      duplicate_choices.each do |y_choice|
        matchup_table << [x_choice, y_choice]
      end
    end

    $logger.debug("Generating victory table")

    matchup_table.each do |matchup|
      electorate.issue.temp_options = matchup
      victory_table <<  plurality_decider(electorate)
    end

    $logger.debug("Parsing victory table")

    victory_table.each do |possible_winner,voting_summary|
       matchup_winners << possible_winner
       losers = (voting_summary.keys - [possible_winner])
       losers.each do |loser|
         definite_losers << loser
       end
    end

    possible_winner = (matchup_winners.uniq - definite_losers.uniq)
    if possible_winner.size == 1
      [possible_winner[0], victory_table]
    else
      [:no_condor, victory_table]
    end
  end

  def copeland_decider(electorate)
    first_outcome = condorcet_decider(electorate)
    possible_winner = first_outcome[0]
    victory_table = first_outcome[1]

    if possible_winner == :no_condor
      matchup_winner_summary = victory_table.reduce(Hash.new(0)) { |result, element| result[element[0]] += 1; result }
      copeland_winner = top_choices(matchup_winner_summary, 1, :return_if_tie)
      if copeland_winner == :tie then [:tie, victory_table] else [copeland_winner[0], victory_table] end
    else
      [possible_winner, victory_table]
    end
  end

  def kemeny_young_decider(electorate)

    ranking_scores = Hash.new(0)
    victory_table = condorcet_decider(electorate)[1]
    short_victory_table = victory_table.reduce([]) { |result, element| result << element.pop; result }
    duplicate_choices = electorate.issue.options
    possible_rankings = duplicate_choices.permutation(duplicate_choices.size).to_a

    short_victory_table.each do |matchup_summary|
      matchup_summary.delete_if { |key| key == :unranked }
    end

    possible_rankings.each do |ranking|
      short_victory_table.each do |matchup_summary|
        candidate_one_score = ranking.index(matchup_summary.keys[0])

        if ranking.index(matchup_summary.keys[1]) == nil
          candidate_two_score = candidate_one_score + 1
        else
          candidate_two_score = ranking.index(matchup_summary.keys[1])
        end

        if candidate_one_score < candidate_two_score
          ranking_scores[ranking] += matchup_summary.values[0]
        else
          ranking_scores[ranking] += matchup_summary.values[1]
        end
      end

      ranking_scores[ranking] = ranking_scores[ranking].round(2)
    end

    top_ranking = top_choices(ranking_scores, 1, :return_if_tie)
      if top_ranking == :tie
        [:tie, ranking_scores]
      else
        top_ranking = top_ranking.flatten
        [top_ranking, ranking_scores]
      end
  end

  def minimax_decider(electorate)
    first_outcome = condorcet_decider(electorate)
    possible_winner = first_outcome[0]
    victory_table = first_outcome[1]
    short_victory_table = victory_table.reduce([]) { |result, element| result << element.pop; result }
    opposition_table = { }

    if possible_winner == :no_condor
      short_victory_table.each do |matchup|
              candidate_a = matchup.keys[0]
              candidate_b = matchup.keys[1]
              opposition_to_a = matchup[candidate_b]
              opposition_to_b = matchup[candidate_a]
              opposition_table[candidate_a] = opposition_to_a if opposition_table[candidate_a] < opposition_to_a
              opposition_table[candidate_b] = opposition_to_b if opposition_table[candidate_b] < opposition_to_b
            end
      possible_winner = bottom_choices(opposition_table,1,false)
      [possible_winner, short_victory_table]
    else
      [possible_winner, victory_table]
    end
  end

  def ranked_pairs_decider(electorate)
    candidates = electorate.issue.options
    graph_index = { }
    candidates.each_index do |i|
      graph_index[candidates[i]] = i + 1
    end

    first_outcome = condorcet_decider(electorate)
    possible_winner = first_outcome[0]
    victory_table = first_outcome[1]
    short_victory_table = victory_table.reduce([]) { |result, element| result << element.pop; result }
    graph = Array.new(graph_index.size) { Array.new(graph_index.size,0) }

    if possible_winner == :no_condor
      short_victory_table.each do |matchup|
              keys = matchup.keys
              values = matchup.values

              key_index_0 = graph_index[keys[0]]
              key_index_1 = graph_index[keys[1]]

              if values[0] > 0.5
                graph_index[keys[0]]
                graph[key_index_0 - 1][key_index_1 - 1] = values[0]
              elsif values[1] > 0.5
                puts values[1]
                graph[key_index_1 - 1][key_index_0 - 1] = values[1]
              end
      end
    else
      [possible_winner,victory_table]
    end


  end

end



class Electorate

  attr_reader :voters, :issue
  attr_accessor :voting_system, :total_votes

  def initialize(issue, voters, voting_system = :plurality)
    @issue = issue
    @voters = voters
    @voting_system = voting_system
  end

  def add_preference_group(ballot_choices, count)
    weight = count.to_f / total_votes.to_f
    ballot = Ballot.new(@issue, ballot_choices)
    voters << Voter.new('Jane Doe', ballot, weight)
  end

 #bigdecimal has different rounding strategies

end

class Voter
  attr_reader :weight, :ballot
  attr_accessor :voter_name

  def initialize(voter_name, ballot, weight = 1)
    @voter_name = voter_name
    @weight = weight
    @ballot = ballot
  end
end

class Issue
  attr_reader :issue_name, :options
  attr_accessor :temp_options

  def initialize(issue_name, options)
    @issue_name = issue_name

    raise ArgumentError.new("Duplicate options not allowed for an issue") if not options.is_a_set?
    #TODO:  USE SET TO AVOID UNIQUENESS CHECKS

    @options = options
    @temp_options = options
  end

  def reset_options
    @temp_options = @options
  end

end

class Ballot
  attr_reader :issue, :choices
  attr_accessor :original_choices

  def initialize(issue, choices)
    @issue = issue

    #TODO: Add logger error messages to all raised errors that are handleable, or build the error raising into the logging
    #raise ArgumentError.new('Choices are required on the ballot') if choices == nil || choices.size == 0
    #raise ArgumentError.new("Duplicate choices not allowed on the ballot") if not choices.is_a_set?
    #TODO: Handle the error by removing the duplicates

    @choices = choices
    @original_choices = choices
  end
end

class Decider
  include VoteProcessing

  attr_accessor :voting_system, :sig_figs, :tie_option, :unranked_option

  TIE_OPTIONS = [:break_randomly, :raise_error, :return_if_tie]
  UNRANKED_CHOICE_OPTIONS = [:spoiled_ballot, :ranked_last, :raise_error, :zero_weight]

  def initialize(voting_system = :plurality, sig_figs = 2, tie_option = 2, unranked_option = 3)
    @voting_system = voting_system
    @sig_figs = sig_figs
    @tie_option = TIE_OPTIONS[tie_option]
    @unranked_option = UNRANKED_CHOICE_OPTIONS[unranked_option]
  end

  def activate_decider(electorate)
    @voting_system = electorate.voting_system

  #TODO: Raise an flag if the unranked_option variable is set to :ranked_last, and the voting system doesn't support equal rankings
    #TODO:  If the flag is set and more than one unranked choice is on a ballot, then raise an error

   logger.debug("\n\n---BEGIN SCENARIO---\nVoting System: #@voting_system \n")

   public_send("#{voting_system}_decider", electorate)

    #decide(electorate, voting_system)

    #decide_voting_system

    #case voting_system
    #          when :plurality then plurality_decider(electorate)
    #          when :two_round then two_round_decider(electorate)
    #          when :exhaustive_ballot then exhaustive_ballot_decider(electorate)
    #          when :condorcet then condorcet_decider(electorate)
    #          when :copeland then copeland_decider(electorate)
    #          when :kemeny_young then kemeny_young_decider(electorate)
    #          when :minimax then minimax_decider(electorate)
    #          when :ranked_pairs then ranked_pairs_decider(electorate)
    #          else raise NotImplementedError.new('That voting system is not supported')
    #end
  end

  def equal_rankings?(voting_system)
    result = case voting_system
             when :plurality then false
             when :two_round then false
             when :exhaustive_ballot then false
             when :condorcet then true
             when :copeland then true
             when :kemeny_young then true
             when :minimax then true
             when :ranked_pairs then true
             else raise ArgumentError.new('Unknown if that system allows equal rankings')
    end
  end
end



a = Decider.new
#test_voters = { 'a' => 0.2, 'b' => 0.3, 'c' => 0.1, 'd' => 0.3}
#puts Benchmark.measure { 10000.times do a.top_choices(test_voters, 2) end }





#Voters should be able to create ballots that include an authentication key.
#The authentication key is created using a combination of the voter's individual authentication key, and the
#issue's authentication key.




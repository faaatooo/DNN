// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16 <0.9.0;
import "./User.sol";
import "./DNNToken.sol";

contract ReviewProcess {
    uint constant REQUIRED_VOTER_REQUESTS = 10;
    uint constant REQUIRED_VOTERS = 7;
    uint constant WRITER_FEE = 100;
    uint constant VOTING_PERIOD_DURATION = 3 days;
    
    // Addresses where the DNNToken and User contracts have been deployed
    address dnnTokenAddress;
    address userContractAddress;
    DNNToken dnnToken;
    User userContract;
    address voterAddress;
    
    enum VoteStatus { none, accept, reject }
    enum ArticleStatus { none, waitingForVoters, voting, done }
    
    struct Vote {
        VoteStatus personalVote;
        VoteStatus poolVote;
        string feedbackIpfsHash;
    }
    
    struct Article {
        string ipfsHash;
        ArticleStatus status;
        address submittedBy;
        uint256 submissionTime;
        address[] voteRequests;
        uint32 collateralTotal;
        mapping(address => uint256) requestTimes;
        mapping(address => uint32) collateralAmounts;
        mapping(address => bool) votingRights;
        mapping(address => Vote) votes;
        uint8 voteCount;
    }
    
    mapping(bytes32 => Article) submittedArticles;
    
    // Events that get triggered when article gets submitted, accepted/rejected or voting period has expired
    event ArticleSubmitted(bytes32 articleId);
    event VotingStarted(bytes32 articleId);
    event ArticleAccepted(bytes32 articleId);
    event ArticleRejected(bytes32 articleId);
    event VotingPeriodExpired(bytes32 articleId);
   
    // Debugging events 
    event BroadcastMessage(string message);
    event SendTokens(address toAddress, uint256 amount, string reason);
    
    function _ReviewProcess() public{
        dnnToken = DNNToken(dnnTokenAddress);
        userContract = User(userContractAddress);
    }
    
    // Submit article with given IPFS hash for review
    function submitArticleForReview(string memory articleIpfsHash) public{
        // Make sure that the caller has right permissions to do this
        User.UserType userType = userContract.retrieveUserType(msg.sender);
        
        if(userType != User.UserType.writer) {
            revert();
        }
        
        // Generate new article ID
        bytes32 articleId ;
        
        // Deduct write fee from the sender
        if(dnnToken.transferFrom(msg.sender, address(this), WRITER_FEE)) {
            emit BroadcastMessage("Successfully deducted writer fee");
        } else {
            emit BroadcastMessage("Could not deduct writer fee");
            revert();
        }
        
        // Create new article object and initialize it's fields
        Article storage newArticle;
        newArticle.ipfsHash = articleIpfsHash;
        newArticle.status = ArticleStatus.waitingForVoters;
        newArticle.submittedBy = msg.sender;
        newArticle.submissionTime = block.timestamp;
        Article storage NEWarticle;
        NEWarticle = submittedArticles[articleId];
        newArticle = NEWarticle;
        // Broadcast ArticleSubmitted event
        emit ArticleSubmitted(articleId);
    }
    
    // Request the right to vote on the given article
    function askToVote(uint32 collateralAmount) public{
        // Make sure that the caller has right permissions to do this
        User.UserType userType = userContract.retrieveUserType(msg.sender);
        
        if(userType != User.UserType.reviewer) {
            revert();
        }
        
        bytes32 articleId;
        
        Article storage article = submittedArticles[articleId];
        
        // Make sure that given article has the right status
        if(article.status != ArticleStatus.waitingForVoters) {
            revert();
        }
        
        // Reviewers shouldn't be allowed to submit requests more than once
        if(article.collateralAmounts[msg.sender] > 0) {
            revert();
        }
        
        // Deduct collateral tokens from the sender
        if(dnnToken.transferFrom(msg.sender, address(this), collateralAmount)) {
            emit BroadcastMessage("Successfully collateral tokens");
        } else {
            emit BroadcastMessage("Could not deduct collateral tokens");
            revert();
        }
        
        // Store the request
        article.voteRequests.push(msg.sender);
        article.requestTimes[msg.sender] = block.timestamp;
        article.collateralAmounts[msg.sender] = collateralAmount;
        
        emit BroadcastMessage("Vote request stored");
        
        // Check if the number of requests has reached the limit and, if so, execute voter selection process
        if(article.voteRequests.length == REQUIRED_VOTER_REQUESTS) {
            emit BroadcastMessage("Enough requests received, starting selection process");
            emit VotingStarted(articleId);
            
            selectVoters(articleId);
        }
    }
 
    // Vote on the article with given IPFS hash
    function vote( VoteStatus personalVote, VoteStatus poolVote, string memory feedbackIpfsHash) public {
        // Make sure that the caller has right permissions to do this
        User.UserType userType = userContract.retrieveUserType(msg.sender);
        
        if(userType != User.UserType.reviewer) {
            revert();
        }
        
        bytes32 articleId ;
        
        Article storage article = submittedArticles[articleId];
        
        // Make sure that given article has the right status
        if(article.status != ArticleStatus.voting) {
            revert();
        }
        
        /* Make sure that the current user has been granted right to vote on this article
           and that he hasn't already voted */
        if(article.votingRights[msg.sender] != true  || article.votes[msg.sender].personalVote != VoteStatus.none) {
            revert();
        }
        
        // Store the vote
        Vote memory newVote;
        newVote.personalVote = personalVote;
        newVote.poolVote = poolVote;
        newVote.feedbackIpfsHash = feedbackIpfsHash;
        article.votes[msg.sender] = newVote;
        article.voteCount++;
        
        emit BroadcastMessage("Vote stored");
        
        // Check whether this was the last required vote and, if so, trigger the article publishing and token disbursement process
        if(article.voteCount == REQUIRED_VOTERS) {
            emit BroadcastMessage("Enough votes received, processing votes");
            processVotes(articleId);
        }
    }
    
    // Check if given article's voting period has expired and, if so, initialize vote processing
    function checkForExpiration(bytes32 articleId) public{
        Article storage article = submittedArticles[articleId];
        
        if(block.timestamp > article.submissionTime + VOTING_PERIOD_DURATION) {
            emit VotingPeriodExpired(articleId);
            processVotes(articleId);
        }
    }
    
    function selectVoters(bytes32 articleId) internal {
         Article storage article = submittedArticles[articleId];
        
        // Sort voter addresses by collateral amount, from highest to lowest
        sortVotersByCollateral(articleId, 0, int(article.voteRequests.length - 1));
        
        // Grant voting rights to the specified top number of voters 
        for(uint i = 0; i < REQUIRED_VOTERS; i++) {
            voterAddress = article.voteRequests[i];
            
            article.votingRights[voterAddress] = true;
            article.collateralTotal += article.collateralAmounts[voterAddress];
        }
        
        // Refund the remaining reviewers
        for(uint i = REQUIRED_VOTERS; i < article.voteRequests.length; i++) {
            voterAddress = article.voteRequests[i];
            
            dnnToken.transfer(voterAddress, article.collateralAmounts[voterAddress]);
            emit SendTokens(voterAddress, article.collateralAmounts[voterAddress], "Collateral refund");
        }
        
        // Update article status
        article.status = ArticleStatus.voting;
        
        emit BroadcastMessage("Voters selected");
    }
    
    
    function processVotes(bytes32 articleId) internal {
         Article storage article = submittedArticles[articleId];
        
        // Determine voting result for the given article
        VoteStatus voteResult = getVoteResult(articleId);
        
        // The total amount of lost collateral tokens for this voting round
        uint32 totalLostCollateral = 0;
        /* The number of parties that should receive a share of lost collateral
           Initially set to 1 (for writer who submitted the article), but it will increase during processing below */
        uint8 collateralLossShares = 1;
        address[8] memory collateralLossReceivers;
        collateralLossReceivers[0] = article.submittedBy;
        
        address curAddress;
        VoteStatus curVote;
        
        for(uint i = 0; i < REQUIRED_VOTERS; i++) {
            curAddress = article.voteRequests[i];
            curVote = article.votes[curAddress].personalVote;
            
            if(curVote != VoteStatus.none) {
                uint256 curCollateralShare = (article.collateralAmounts[curAddress] * WRITER_FEE) / article.collateralTotal;
                
                // Send share of writer fee tokens to this voter
                dnnToken.transfer(curAddress, curCollateralShare);
                emit SendTokens(curAddress, curCollateralShare, "Writer fee share");
                
                // Check whether this voter should receive collateral refund
                if(curVote == voteResult) {
                    // Send collateral refund to the voter
                    dnnToken.transfer(curAddress, article.collateralAmounts[curAddress]);
                    emit SendTokens(curAddress, article.collateralAmounts[curAddress], "Collateral refund");
                    
                    // Include this voter into collateral shared pool
                    collateralLossReceivers[collateralLossShares] = curAddress;
                    collateralLossShares++;
                } else {
                    // "Wrong" vote, use this voter's collateral for the shared pool
                    totalLostCollateral += article.collateralAmounts[curAddress];
                }
            } else {
                // This voter has been granted right to vote but hasn't done so, so he should lose his collateral
                totalLostCollateral += article.collateralAmounts[curAddress];
            }
        }
        
        // Disburse lost collateral among writer and correct voters
        uint32 collateralShareAmount = totalLostCollateral / collateralLossShares;
        
        if(collateralShareAmount > 0) {
            // Send a share of lost collateral to the writer as well as each correct voter
            for(uint i = 0; i < collateralLossShares; i++) {
                address curReceiver = collateralLossReceivers[i];
            
                dnnToken.transfer(curReceiver, collateralShareAmount);
                emit SendTokens(curReceiver, collateralShareAmount, "Lost collateral share");
             }
        }
        
        if(voteResult == VoteStatus.accept) {
            emit ArticleAccepted(articleId);
        } else if(voteResult == VoteStatus.reject) {
            emit ArticleRejected(articleId);
        }

        article.status = ArticleStatus.done;
    }
    
    function getVoteResult(bytes32 articleId) internal returns (VoteStatus) {
        Article storage article = submittedArticles[articleId];
        VoteStatus curVote;
        
        int8 result;
        
        for(uint i = 0; i < REQUIRED_VOTERS; i++) {
            curVote = article.votes[article.voteRequests[i]].personalVote;
            
            if(curVote == VoteStatus.accept) {
                result++;
            } else if(curVote == VoteStatus.reject) {
                result--;
            }
        }
        
        return result > 0 ? VoteStatus.accept : VoteStatus.reject;
    }
    
    function sortVotersByCollateral(bytes32 articleId, int left, int right) internal {
         Article storage article = submittedArticles[articleId];
        
        int pivotPosition = left + (right - left) / 2;
        address pivotAddress = article.voteRequests[uint(pivotPosition)];
        uint pivotAmount = article.collateralAmounts[pivotAddress];
        uint pivotTime = article.requestTimes[pivotAddress];
        
        int i = left;
        int j = right;
        
        while (i < j) {
            while (i < right && isRequestGreaterThanPivot(articleId, uint(i), pivotAmount, pivotTime)) i++;
            while (j > 0 && isRequestSmallerThanPivot(articleId, uint(j), pivotAmount, pivotTime)) j--;
            
            if (i < j) {
                address temp = article.voteRequests[uint(i)];
                article.voteRequests[uint(i)] = article.voteRequests[uint(j)];
                article.voteRequests[uint(j)] = temp;
                i++;
                j--;
            } 
        }
    
        if (left < j) {
            sortVotersByCollateral(articleId, left, j);
        }
        
        if (right > j + 1) {
            sortVotersByCollateral(articleId, j + 1, right);
        }
    }
    
    function isRequestGreaterThanPivot(bytes32 articleId, uint requestIndex, uint pivotAmount, uint256 pivotTime) internal returns (bool) {
         Article storage article = submittedArticles[articleId];
        
        return article.collateralAmounts[article.voteRequests[requestIndex]] > pivotAmount || 
            (article.collateralAmounts[article.voteRequests[requestIndex]] == pivotAmount && article.requestTimes[article.voteRequests[requestIndex]] < pivotTime);
    }
    
    function isRequestSmallerThanPivot(bytes32 articleId, uint requestIndex, uint pivotAmount, uint256 pivotTime) internal returns (bool) {
         Article storage article = submittedArticles[articleId];
        
        return article.collateralAmounts[article.voteRequests[requestIndex]] < pivotAmount || 
            (article.collateralAmounts[article.voteRequests[requestIndex]] == pivotAmount && article.requestTimes[article.voteRequests[requestIndex]] > pivotTime);
    }
}

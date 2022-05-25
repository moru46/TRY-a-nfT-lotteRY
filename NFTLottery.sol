// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "contracts/artifacts/NFT_KITTY.sol";

struct PlayerAccountTickets{
    mapping (uint => uint []) ticketList; //for each key, it contains the 5 numbers + special number
    uint nTicket;
    uint [] nMatches; //for each ticket, store the number of matches
    uint [] nMatchesPB; //for each ticket, store if the special number has been found
}

struct nftPrize {
    string nftDescription; //brief description about the ntf prize
    uint rank; //rank of the prize inside the lottery
    kittyNft nft; //nft prize
    bool assigned;
    uint tokenId;

}

contract Lottery {
    address public lotteryOperator;
    address payable[] public players; //lottery players
    mapping (address => PlayerAccountTickets) private playersTickets; 
    bool public isActive; //to know if the round is active or not
    bool public isLotteryActive; //to know if the prize has been given to the players or not
    uint public constant duration = 100; //number of blocks 
    uint public roundClosing;
    uint public blockNumber; //number of the first block related to a specific round
    uint [] public numbersDrawn;
    uint public Kvalue; //parameter for the numbers drawn
    
    //nft
    kittyNft nft;
 //   mapping (uint => nftPrize) collectibles; //in this mapping, each key correspond to a collectibles, where the rank of the collectibles is inside it
    nftPrize [] public collectibles;
    //uint [] private arrayIndex ;

    constructor(uint _K){
        lotteryOperator = msg.sender;
        isActive = false;
        isLotteryActive = true;
        Kvalue = _K;
    }

    //TODO: generate the nft prize when start new round
    // checks if the previous round is finished, and, if that's the case, starts a new round.
    function startRound() public  {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");
        require(isActive == false, "Wait the end of previous round before starting a new one");
       // require(prizeOk == true, "Lottery Operator must give the prize to players before start a new round");
        
        players = new address payable[](0); //remove all previous players
        //playersTickets = new mapping (address => PlayerAccountTickets);

        isActive = true; //start new round
        blockNumber = block.number;
        roundClosing = blockNumber + duration; //from the first block up to the n' block

        for(uint i=0; i<8;i++){
            if( collectibles[i].assigned == false) //if there are some prize not assignen, i do not regenerate another one and reuse it
                continue;
            nft = new kittyNft(i+1,"pippo");
            collectibles[i].tokenId = nft.mint("");
            collectibles[i].nft = nft;
            collectibles[i].rank = i+1;
            collectibles[i].assigned = false;

        }
    }

    function closeRound() public payable {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");
        require(isActive == false, "A new round must be started before calling closeRound");
    }

    //Allows users to buy a ticket. The numbers picked by a user in 
    //that ticket are passed as input of the function. The function checks 
    //if there is a round active, otherwise the function returns an error code.
    //TODO: checks how to pass the number choose by the player
    function buy(uint [] memory _numbers) public payable returns (bool){
        require(isActive == false, "Round is not active, wait for new one!");
        require(isLotteryActive == false, "Lottery is not active at the moment");        
        require(msg.value == 1 ether, "Fee of 1 ether is required to buy a ticket"); //require to enter the lottery and buy a ticket

        //TODO get the numbers from input and check the input value
        uint nlen = _numbers.length;
        require( nlen == 6, "You must choice six numbers to play!");

        for( uint i = 0; i < nlen; i++){
            if(i != 5){
                require( _numbers[i] >= 1 && _numbers[i] <= 69);
            }
            else {
                require( _numbers[i] >= 1 && _numbers[i] <= 26);
            }
        }

        //TODO check if there are some repetitions and notify it
        
        playersTickets[msg.sender].nTicket += 1; //add new ticket to the list
        uint num = playersTickets[msg.sender].nTicket;
        //if nTicket == 1, is the first ticket for that user, so i add him to the array of user
        if ( num == 1 ){
            players.push(payable(msg.sender)); //add the player to the array
        }
        for(uint i = 0; i < 6; i++){
            playersTickets[msg.sender].ticketList[num].push(_numbers[i]); //add the list of numbers
        }

        return true;
    }

    //TODO check the time for drawn
    //used by the lottery operator to draw numbers of the current lottery round
    //function drawNumbers(uint K) public returns(uint[] memory){
    function drawNumbers() public returns(bool){ 
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");
        // Considering that a block is mined every 12 seconds on average,  
        // waiting other 25 means waiting other 5 minutes to draw numebrs. 
        require(block.number >= duration + Kvalue, "Too early to draw numbers");

        isActive = false; //stop the current round and start to drawn the numbers
 
        //idea: use block.timestamp as random variable K

        bytes32 bhash = blockhash(duration + Kvalue); 
        bytes memory bytesArray = new bytes(32); 
        for (uint i; i <32; i++){ 
            bytesArray[i] =bhash[i]; 
        } 
        bytes32 rand=keccak256(bytesArray); 
        for (uint i=0; i<5; i++){ 
    
            uint x = (uint(rand) % 69) + 1;
            numbersDrawn[i] = x;
            //check if the number is repeated or not
            for (uint j = 0; j < i; j++){
                if ( x == numbersDrawn[j] ){
                    //in case of repetiton, i do another draw for that position
                    i -= 1;
                }
            }
        }

        numbersDrawn[5] = (uint(rand) % 26) + 1; //powerball number
        return true;
    }

    //players who takes part to this lottery round
    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }

    /*function getRandomNumber() public view returns (uint) {
        return uint(keccak256(abi.encodePacked(lotteryOperator, block.timestamp)));
    }*/

    //check the winners of the lottery by inspecting all the tickets
    function checkWinners() public {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");
        
        for (uint i = 0; i < players.length; i++){ //for each player in the lottery round
            for ( uint j = 1; j <= playersTickets[players[i]].nTicket; j++){ //for each ticket
                uint totMatch = 0;
                for ( uint k = 0; k < 6; k++ ){
                    if ( k == 5 ){ //powerball match
                        if ( numbersDrawn[k] == playersTickets[players[i]].ticketList[j][k] ){
                            playersTickets[players[i]].nMatchesPB.push(1);
                        }
                        else {
                             playersTickets[players[i]].nMatchesPB.push(0);
                        }
                        playersTickets[players[i]].nMatches.push(totMatch); //update the total amount of matches for "normal" numbers
                    }
                    if ( numbersDrawn[k] == playersTickets[players[i]].ticketList[j][k] ){
                            totMatch += 1;
                           // playersTickets[players[i]].nMatches[j-1] += 1;
                        }
                }
            }
        }
    }

    //used by lottery operator to distribute the prizes of the current lottery round
    //inspect all the result in playersTickets and gives the prize to the player
    //if one prize has been already assigned to a player, will be generated a new one of the same rank
    function givePrizes() public {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");

        for (uint i = 0; i < players.length; i++){
            for ( uint j = 0; j < playersTickets[players[i]].nMatches.length; j++){
                for ( uint k = 0; k < 6; k++ ){
                    if ( k == 5 ){
                        if ( numbersDrawn[k] == playersTickets[players[i]].ticketList[j][k] ){
                            playersTickets[players[i]].nMatchesPB[j] = 1;
                        }
                    }
                    if ( numbersDrawn[k] == playersTickets[players[i]].ticketList[j][k] ){
                            playersTickets[players[i]].nMatches[j] += 1;
                        }
                }
            }
        }

    } 


    function closeLottery() public {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");

        isLotteryActive = false; //deactivate the lottery
        //TODO: rimborsare i giocatori



    }

}

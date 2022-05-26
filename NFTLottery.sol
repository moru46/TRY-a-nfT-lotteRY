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
    address payable public lotteryOperator;
    address payable[] public players; //lottery players
    mapping (address => PlayerAccountTickets) private playersTickets; 
    bool public isActive; //to know if the round is active or not
    bool public isLotteryActive; //to know if the prize has been given to the players or not
    uint public constant duration = 100; //number of blocks 
    uint public roundClosing;
    uint public blockNumber; //number of the first block related to a specific round
    uint [] public numbersDrawn;
    uint public Kvalue; //parameter for the numbers drawn
    bool public prizeGiven;
    uint public constant ticketPrize = 1 gwei;
    
    //nft
    kittyNft nft;
    //mapping (uint => nftPrize) collectibles; //in this mapping, each key correspond to a collectibles, where the rank of the collectibles is inside it
    nftPrize [] public collectibles;
    //uint [] private arrayIndex ;

    constructor(uint _K){
        lotteryOperator = payable(msg.sender);
        isActive = false;
        isLotteryActive = true;
        Kvalue = _K;
        prizeGiven = true;
    }

    //TODO: generate the nft prize when start new round
    // checks if the previous round is finished, and, if that's the case, starts a new round.
    function startRound() public  {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");
        require(isActive == false, "Wait the end of previous round before starting a new one");
        require(prizeGiven == false, "You must give prize to players before starting a new round");

        prizeGiven = false;
        isActive = true; //start new round
        blockNumber = block.number;
        roundClosing = blockNumber + duration; //from the first block up to the n' block

        for(uint i=0; i<8;i++){
            if( collectibles[i].assigned == false) //if there are some prize not assignen, i do not regenerate another one and reuse it
                continue;
            nft = new kittyNft();
            collectibles[i].tokenId = nft.mint(i);
            collectibles[i].nft = nft;
            collectibles[i].rank = i+1;
            collectibles[i].assigned = false;

        }
    }

    //Allows users to buy a ticket. The numbers picked by a user in 
    //that ticket are passed as input of the function. The function checks 
    //if there is a round active, otherwise the function returns an error code.
    //TODO: checks how to pass the number choose by the player
    function buy(uint [] memory _numbers) public payable returns (bool){
        require(isLotteryActive == false, "Lottery is not active at the moment"); 
        require(isActive == false, "Round is not active, wait for new one!");       
        require(msg.value == 1 gwei, "Fee of 1 gwei is required to buy a ticket"); //require to enter the lottery and buy a ticket

        //TODO get the numbers from input and check the input value
        uint nlen = _numbers.length;
        require( nlen == 6, "You must choice six numbers to play!");

        bool[69] memory pickedNumbers;
        for( uint i = 0; i < 69;i++)
            pickedNumbers[i] = false;

        for( uint i = 0; i < nlen; i++){
            if(i != 5){
                require( _numbers[i] >= 1 && _numbers[i] <= 69, "Number out of range");
                require( !pickedNumbers[_numbers[i]-1], "Duplicated number are not allowed" );

                pickedNumbers[_numbers[i]-1] = true;
            }
            else {
                require( _numbers[i] >= 1 && _numbers[i] <= 26);
                require( !pickedNumbers[_numbers[i]-1], "Duplicated number are not allowed" );

                pickedNumbers[_numbers[i]-1] = true;
            }
        }
        
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

        bool[69] memory pickedNumbers;
        for( uint i = 0; i < 69;i++)
            pickedNumbers[i] = false;

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
            if( !pickedNumbers[x-1] )
                i -= 1;
            else {
                pickedNumbers[x-1] = true;
            }
            /*for (uint j = 0; j < i; j++){
                if ( x == numbersDrawn[j] ){
                    //in case of repetiton, i do another draw for that position
                    i -= 1;
                }
            }*/
        }

        numbersDrawn[5] = (uint(rand) % 26) + 1; //powerball number

        givePrizes();

        return true;
    }

    //check the winners of the lottery by inspecting all the tickets
    //
    //used by lottery operator to distribute the prizes of the current lottery round
    //inspect all the result in playersTickets and gives the prize to the player
    //if one prize has been already assigned to a player, will be generated a new one of the same rank
    function givePrizes() public {
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

        for (uint i = 0; i < players.length; i++){ //for each player in the lottery round
            for ( uint j = 0; j < playersTickets[players[i]].nMatches.length; j++){ //for each ticket
                uint match1 = playersTickets[players[i]].nMatches[j];
                uint match2 = playersTickets[players[i]].nMatchesPB[j];
                uint prizeToAssign;

                if (match1 == 5 && match2 == 1)
                    //assegna classe 1
                    prizeToAssign = 1;
                else if ( match1 == 5 && match2 == 0)
                    //assegna classe 2
                    prizeToAssign = 2;
                else if (match1 == 4 && match2 == 1)
                    //assegna classe 3
                    prizeToAssign = 3;
                else if (match1 == 4 && match2 == 0)
                    //assegna classe 4
                    prizeToAssign = 4;
                else if (match1 == 3 && match2 == 1)
                    //assegna classe 4
                    prizeToAssign = 4;
                else if (match1 == 3 && match2 == 0)
                    //assegna classe 5
                    prizeToAssign = 5;
                else if (match1 == 2 && match2 == 1)
                    //assegna classe 5
                    prizeToAssign = 5;
                else if (match1 == 2 && match2 == 0)
                    //assegna classe 6
                    prizeToAssign = 6;
                else if (match1 == 1 && match2 == 1)
                    //assegna classe 6
                    prizeToAssign = 6;
                else if (match1 == 1 && match2 == 0)
                    //assegna classe 7
                    prizeToAssign = 7;
                else if (match1 == 0 && match2 == 1)
                    //assegna classe 8
                    prizeToAssign = 8;

                //assign the prize and mint a new one
                uint tokendIdWin = nft.getTokenOfClass(prizeToAssign);
                nft.awardItem(players[i],tokendIdWin);
                mint(prizeToAssign);

            }
        }        

        prizeGiven = true;
        lotteryOperator.transfer(address(this).balance);

        players = new address payable[](0); //remove all previous players
        
        //TODO inizializzare mapping ticket
    }

    function mint(uint _classNFT) public {
        require(isLotteryActive == false, "Lottery is not active at the moment");
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        nft.mint(_classNFT);
    }


    function closeLottery() public payable{
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == false, "Lottery is not active at the moment");

        isLotteryActive = false; //deactivate the lottery
        //TODO: rimborsare i giocatori
        if(isActive && !prizeGiven)
            for(uint i = 0; i < players.length; i++)
                players[i].transfer(ticketPrize*playersTickets[players[i]].nTicket);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "contracts/artifacts/NFT_KITTY.sol";

struct PlayerAccountTickets{
    mapping (uint => uint []) ticketList; //for each key, it contains the 5 numbers + special number
    uint nTicket;
    uint [] nMatches; //for each ticket, store the number of matches
    uint [] nMatchesPB; //for each ticket, store if the special number has been found
}

contract Lottery {
    address public lotteryOperator;
    address payable[] public players; //lottery players
    mapping (address => PlayerAccountTickets) private playersTickets; 
    bool public isActive; //to know if the round is active or not
    bool public isLotteryActive; //to know if the prize has been given to the players or not
    uint public constant duration = 5; //number of blocks 5 for test
    uint public roundClosing;
    uint public blockNumber; //number of the first block related to a specific round
    uint [6] public numbersDrawn;
    uint public valueK; //parameter for the numbers drawn
    bool public prizeGiven;
    uint public constant ticketPrize = 1 gwei;
    
    //nft
    kittyNft nft;

    constructor(uint _K) {
        lotteryOperator = msg.sender;
        isActive = false;
        isLotteryActive = true;
        valueK = _K;
        prizeGiven = true;
        nft = new kittyNft();

        for(uint i=0; i<8;i++){
          nft.mint(i+1);
        }

    }

    event newRound(string result);
    event newTicketBought(address buyer,string result);
    event newDrawn(string result);
    event givePrizeToPlayers(address winningPlayer, string result);
    event mintNewNft(string result);
    event closeLotteryEvent(string result);
    event closeLotteryAndRefund(string result);
    event refundLotteryOp(string result);

    function mint(uint _classNFT) public {
        require(isLotteryActive == true, "Lottery is not active at the moment");
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        nft.mint(_classNFT);
        emit mintNewNft("Lottery Operator has minted a new NFT Token");
    }

    //TODO: generate the nft prize when start new round
    // checks if the previous round is finished, and, if that's the case, starts a new round.
    function startNewRound() public  {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == true, "Lottery is not active at the moment");
        require(isActive == false, "Wait the end of previous round before starting a new one");
        require(prizeGiven == true, "You must give prize to players before starting a new round");

        prizeGiven = false;
        isActive = true; //start new round
        blockNumber = block.number;
        roundClosing = blockNumber + duration; //from the first block up to the n' block

        emit newRound("New round is on!");

    }

    //Allows users to buy a ticket. The numbers picked by a user in 
    //that ticket are passed as input of the function. The function checks 
    //if there is a round active, otherwise the function returns an error code.
    //TODO: checks how to pass the number choose by the player
    function buy(uint [] memory _numbers) public payable returns (bool){
        require(isLotteryActive == true, "Lottery is not active at the moment"); 
        require(isActive == true, "Round is not active, wait for new one!");       
        require(msg.value == 5 gwei, "Fee of 5 gwei is required to buy a ticket"); //require to enter the lottery and buy a ticket
        require(block.number <= roundClosing, "Round is over, try later");

        //TODO get the numbers from input and check the input value
        uint nlen = _numbers.length;
        require( nlen == 6, "You must choice six numbers to play!");

        bool[69] memory pickedNumbers;
        for( uint i = 0; i < 69;i++)
            pickedNumbers[i] = false;

        for( uint i = 0; i < nlen; i++){
            if(i != 5){
                require( _numbers[i] >= 1 && _numbers[i] <= 69, "Number out of range: 1-69");
                require( !pickedNumbers[_numbers[i]-1], "Duplicated number are not allowed" );

                pickedNumbers[_numbers[i]-1] = true;
            }
            else {
                require( _numbers[i] >= 1 && _numbers[i] <= 26, "Number out of range: 1-26");

                pickedNumbers[_numbers[i]-1] = true;
            }
        }
        
        playersTickets[msg.sender].nTicket += 1; //add new ticket to the list
        uint num = playersTickets[msg.sender].nTicket;

        if ( num == 1 )
            players.push(payable(msg.sender)); //add the player to the array
        
        for(uint i = 0; i < 6; i++)
            playersTickets[msg.sender].ticketList[num].push(_numbers[i]); //add the list of numbers
        
        emit newTicketBought(msg.sender,"New Ticket bought by the user!");

        return true;
    }

    //used by the lottery operator to draw numbers of the current lottery round
    function drawNumbers() public payable returns(bool){ 
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == true, "Lottery is not active at the moment");
        // Considering that a block is mined every 12 seconds on average,  
        // waiting other 25 means waiting other 5 minutes to draw numebrs. 
        require(block.number >= roundClosing + valueK, "Too early to draw numbers");

        isActive = false; //stop the current round and start to drawn the numbers

        bool[69] memory pickedNumbers;
        for( uint i = 0; i < 69;i++)
            pickedNumbers[i] = false;

        //bytes32 bhash = blockhash(duration + valueK);
        bytes32 bhash = keccak256(abi.encodePacked(block.difficulty, block.timestamp, duration + valueK));
        bytes memory bytesArray = new bytes(32);
        
        for (uint i=0; i<6; i++){ 

            for (uint j = 0; j <32; j++)
                bytesArray[j] = bhash[j];

            bytes32 rand = keccak256(bytesArray);
            

            uint x = (uint(rand) % 69) + 1;
            numbersDrawn[i] = x;
            //check if the number is repeated or not
            if( pickedNumbers[x-1] )
                i -= 1;
            else {
                pickedNumbers[x-1] = true;
            }

            if( i == 5)
                numbersDrawn[5] = (uint(rand) % 26) + 1; //powerball number

            bhash = bhash ^ rand; //xor for each position in bhash

        }

        emit newDrawn("Lottery Operator has drawn the winning numbers! Let's see the winners");

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
        require(isLotteryActive == true, "Lottery is not active at the moment");
        
        for (uint i = 0; i < players.length; i++){ //for each player in the lottery round
            for ( uint j = 1; j <= playersTickets[players[i]].nTicket; j++){ //for each ticket
                uint totMatch = 0;
                for ( uint k = 0; k < 6; k++ ){
                    if ( k == 5 ){ //powerball match
                        if ( numbersDrawn[k] == playersTickets[players[i]].ticketList[j][k] )
                            playersTickets[players[i]].nMatchesPB.push(1);
                        else
                             playersTickets[players[i]].nMatchesPB.push(0);

                        playersTickets[players[i]].nMatches.push(totMatch); //update the total amount of matches for "normal" numbers
                    }
                    if ( numbersDrawn[k] == playersTickets[players[i]].ticketList[j][k] )
                            totMatch += 1;
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

                emit givePrizeToPlayers(players[i],"Player has received his prize");

            }
        }        

        prizeGiven = true;
        payable(lotteryOperator).transfer(address(this).balance);
        emit refundLotteryOp("Lottery Operator has been refund!");

        for(uint i = 0; i < players.length; i++){
            uint tickNumb = playersTickets[players[i]].nTicket;
            for(uint j = 1; j <= tickNumb; j++){
                delete playersTickets[players[i]].ticketList[j];
            }
            playersTickets[players[i]].nTicket = 0;
            delete playersTickets[players[i]].nMatches;
            delete playersTickets[players[i]].nMatchesPB;

        }

        players = new address payable[](0); //remove all previous players

    }

    function closeLottery() public payable{
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isLotteryActive == true, "Lottery is not active at the moment");

        isLotteryActive = false; //deactivate the lottery
        //TODO: rimborsare i giocatori
        if(isActive && !prizeGiven){
            for(uint i = 0; i < players.length; i++)
                players[i].transfer(ticketPrize*playersTickets[players[i]].nTicket);
            emit closeLotteryAndRefund("Players refunded!");
        }

        emit closeLotteryEvent("Lottery Operator has closed the Lottery! ");
    }
}

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
}

contract Lottery {
    address public lotteryOperator;
    address payable[] public players; //lottery players
    mapping (address => PlayerAccountTickets) private playersTickets; 
    bool public isActive; //to know if the round is active or not
    bool public prizeOk; //to know if the prize has been given to the players or not
    uint public constant duration = 100; //number of blocks 
    uint public roundClosing;
    uint public blockNumber; //number of the first block related to a specific round
    uint [] public numbersDrawn; 
    
    //nft
    kittyNft nft;
    mapping (uint => nftPrize) collectibles; //in this mapping, each key correspond to a collectibles, where the rank of the collectibles is inside it

    //uint [] private arrayIndex ;

    constructor() {
        lotteryOperator = msg.sender;
        isActive = false;
        prizeOk = true;
    }

    //total amount for this round
    function getBalanceInRound() public view returns (uint) {
        return address(this).balance;
    }

    //TODO: generate the nft prize when start new round
    // checks if the previous round is finished, and, if that's the case, starts a new round.
    function startRound() public  {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isActive == false, "Wait the end of previous round before starting a new one");
        require(prizeOk == true, "Lottery Operator must give the prize to players before start a new round");
        isActive = true; //start new round
        prizeOk = false;
        blockNumber = block.number;
        roundClosing = blockNumber + duration; //from the first block up to the n' block

        //TODO: generation of the nft
        /*for(uint i=0; i<8;i++)
            arrayIndex.push(i+1);

        for (uint i = 0; i < 8; i++) {
        // get the random number, divide it by our array size and store the mod of that division.
        // this is to make sure the generated random number fits into our required range
        uint256 randomIndex = getRandomNum().mod(arrayIndex.length);
        // draw the current random number by taking the value at the random index
        uint256 resultNumber = arrayIndex[randomIndex];
        // write the last number of the array to the current position.
        // thus we take out the used number from the circulation and store the last number of the array for future use 
        arrayIndex[randomIndex] = arrayIndex[arrayIndex.length - 1];
        // reduce the size of the array by 1 (this deletes the last record i’ve copied at the previous step)
        arrayIndex.pop();*/

        for(uint i=0; i<8;i++){
            nft = new kittyNft();
            uint tokenId = nft.mint("");
            collectibles[tokenId].nft = nft;
            collectibles[tokenId].rank = i+1;
        }
    }

    //Allows users to buy a ticket. The numbers picked by a user in 
    //that ticket are passed as input of the function. The function checks 
    //if there is a round active, otherwise the function returns an error code.
    //TODO: checks how to pass the number choose by the player
    function buy(uint _numbers) public payable {
        require(isActive == false, "Round is not active, wait for new one!");
        require(msg.value > .01 ether, "Minimum fee is required to buy a ticket"); //require to enter the lottery and buy a ticket

        //TODO get the numbers from input and check the input value


        //TODO check if there are some repetitions and notify it
        
        playersTickets[msg.sender].nTicket += 1; //add new ticket to the list
        uint num = playersTickets[msg.sender].nTicket;
        //if nTicket == 1, is the first ticket for that user, so i add him to the array of user
        if ( num == 1 ){
            //add the player to the array
            players.push(payable(msg.sender));
        }
        for(uint i = 0; i < 6; i++){
            playersTickets[msg.sender].ticketList[num].push(_numbers); //add the list of numbers
        }
    }

    //used by the lottery operator to draw numbers of the current lottery round
    function drawNumbers(uint K) public returns(uint[] memory){ 
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator"); 
        // Considering that a block is mined every 12 seconds on average,  
        // waiting other 25 means waiting other 5 minutes to draw numebrs. 
        require(block.number >= duration + 25, "Too early to draw numbers");

        isActive = false; //stop the current round and start to drawn the numbers
 
        //idea: use block.timestamp as random variable K

        bytes32 bhash = blockhash(duration + block.timestamp); 
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

    }

    //players who takes part to this lottery round
    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }

    /*function getRandomNumber() public view returns (uint) {
        return uint(keccak256(abi.encodePacked(lotteryOperator, block.timestamp)));
    }*/

    //check the winners of the lottery by inspecting al the tickets
    function checkWinners() public {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        
        for (uint i = 0; i < players.length; i++){
            for ( uint j = 1; j <= playersTickets[players[i]].nTicket; j++){
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
         require(isActive == true, "Round is active, wait for the end of it!");



    }

}

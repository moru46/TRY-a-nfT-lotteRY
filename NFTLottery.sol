// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "contracts/artifacts/NFT_KITTY.sol";

struct PlayerAccountTickets{
    mapping (uint => uint []) ticketList; //for each key, it contains the 5 numbers + special number
    uint nTicket;
}

struct nftPrize {
    string nftDescription; //brief description about the ntf prize
    kittyNft nft; //nft prize
    uint rank; //rank of the prize inside the lottery
}

contract Lottery {
    address public lotteryOperator;
    address payable[] public players; //lottery players
    mapping (address => PlayerAccountTickets) private playersTickets; 
    //accesso tipo: playersTickets[address].ticketList[numeroTicket].push(numeroGiocato)
    //numeroTicket deve essere poi aggiornato e prima ancora prelevato
    bool public isActive; //to know if the round is active or not
    uint public constant duration = 100; //number of blocks 
    uint public roundClosing;
    uint public blockNumber; //number of the first block related to a specific round
    

    //nft
    kittyNft nft; //utile???
    //in this mapping, each key correspond to a collectibles, where the rank of the collectibles is inside it
    mapping (uint => nftPrize) collectibles;

    uint [] private arrayIndex ;

    constructor() {
        lotteryOperator = msg.sender;
        isActive = false; 
    }

    //total amount for this round
    function getBalanceInRound() public view returns (uint) {
        return address(this).balance;
    }

    //TODO: generate the nft prize when start new round
    function startRound() public  {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        require(isActive == false, "Wait the end of previous round before starting a new one");
        isActive = true;
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

    //TODO: checks if a round is active or not, otherwise return an error code
    function buy(string memory _numbers) public payable {
        require(msg.value > .01 ether); //require to enter the lottery and buy a ticket
        //TODO get the numbers from input and check the input value
        

        // address of player entering lottery
        players.push(payable(msg.sender));
    }

    //players who takes part to this lottery round
    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }

    function getRandomNumber() public view returns (uint) {
        return uint(keccak256(abi.encodePacked(lotteryOperator, block.timestamp)));
    }

    function pickWinner() public {
        require(msg.sender == lotteryOperator, "This function is only for the Lottery Operator");
        uint index = getRandomNumber() % players.length;
        players[index].transfer(address(this).balance);

       // lotteryHistory[lotteryId] = players[index];
       // lotteryId++;
        

        // reset the state of the contract
        players = new address payable[](0);
    }

}

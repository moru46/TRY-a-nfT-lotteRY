// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

struct PlayerAccountTickets{
    mapping (uint => uint []) ticketList; //for each key, it contains the 5 numbers + special number
    uint nTicket;
}

contract Lottery {
    address public lotteryOperator;
    address payable[] public players; //lottery players
    //uint public lotteryId;
    mapping (address => PlayerAccountTickets) private playersTickets; //mapping for tickets
    //accesso tipo: playersTickets[address].ticketList[numeroTicket].push(numeroGiocato)
    //numeroTicket deve essere poi aggiornato e prima ancora prelevato

    constructor() {
        lotteryOperator = msg.sender;
        //lotteryId = 1;
    }

    //TODO: checks if a round is active or not, otherwise return an error code
    function buy() public payable {
        require(msg.value > .01 ether);

        // address of player entering lottery
        players.push(payable(msg.sender));
    }

    /*function getWinnerByLottery(uint lottery) public view returns (address payable) {
        return lotteryHistory[lottery];
    }*/

    //total amount for this round
    function getBalanceInRound() public view returns (uint) {
        return address(this).balance;
    }

    //players who takes part to this lottery round
    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }

    function getRandomNumber() public view returns (uint) {
        return uint(keccak256(abi.encodePacked(lotteryOperator, block.timestamp)));
    }

    function pickWinner() public onlyowner {
        uint index = getRandomNumber() % players.length;
        players[index].transfer(address(this).balance);

       // lotteryHistory[lotteryId] = players[index];
       // lotteryId++;
        

        // reset the state of the contract
        players = new address payable[](0);
    }

    modifier onlyowner() {
      require(msg.sender == lotteryOperator);
      _;
    }
}
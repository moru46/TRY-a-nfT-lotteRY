const { expect } = require("chai");
const { should } = require("chai");
const { assert } = require("chai");

describe("Lottery Tests", function(){

    it("Check deployer of the contract", async function () {
        const metadata = JSON.parse(await remix.call('fileManager', 'getFile', 'contracts/artifacts/Lottery.json'))
        const accounts = await web3.eth.getAccounts()

        const signer = (new ethers.providers.Web3Provider(web3Provider)).getSigner()
        let Try = new ethers.ContractFactory(metadata.abi, metadata.data.bytecode.object, signer);
        let try_contract = await Try.deploy(1);
        console.log('Storage contract Address: ' + try_contract.address);
        await try_contract.deployed()

    });

    it("should be a test of the lottery", async function () {
        const artifactsPath = 'contracts/artifacts/Lottery.json' // Change this for different path
        const metadata = JSON.parse(await remix.call('fileManager', 'getFile', artifactsPath))
        const accounts = await web3.eth.getAccounts()
        let contract = new web3.eth.Contract(metadata.abi)
        let failReason = null;
        contract = contract.deploy({
            data: metadata.data.bytecode.object,
            arguments: [1]
        })

        try_contract = await contract.send({
            from: accounts[0],
            gas: 15000000000,
            gasPrice: '30000000000'
        })
        console.log(try_contract.options.address)

        let owner = await try_contract.methods.owner().call()
        let owner_balance = await web3.eth.getBalance(owner)
        console.log("Owner ----> " + owner + " With balance: " + owner_balance + " WEI")


    });

    it("Check deployer of the contract", async function () {
        const metadata = JSON.parse(await remix.call('fileManager', 'getFile', 'contracts/artifacts/Lottery.json'))
        const accounts = await web3.eth.getAccounts()

        const signer = (new ethers.providers.Web3Provider(web3Provider)).getSigner();
        let Try = new ethers.ContractFactory(metadata.abi, metadata.data.bytecode.object, signer);
        let try_contract = await Try.deploy(1);
        //console.log('Storage contract Address: ' + try_contract.address);
        await try_contract.deployed();

        var manager_address = await try_contract.owner();
        var deployer_address = accounts[0];

        assert.equal(manager_address,deployer_address, "manager is not deployer");



    });

    
});

const BigNumber = web3.BigNumber;

    require('chai')
    .use(require("chai-bignumber")(BigNumber))
    .use(require('chai-as-promised'))
    .should();

// test/.TimeLockStorage_Test.js
const QDAO = artifacts.require("QDAO");
const TokenLocker = artifacts.require("TimeLockedTokenStorage");

const ETHER = 10**18;
const TOKEN = 10**18;
const ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

const increaseTime = (addSeconds) => new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync(
        [{jsonrpc: "2.0", method: "evm_increaseTime", params: [addSeconds], id: 0},
            {jsonrpc: "2.0", method: "evm_mine", params: [], id: 0}
        ],
        function (error, result) {
            if (error) {
                reject(error);
            } else {
                resolve(result);
            }
        }
    );
});
const snapshot = () => new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync(
        {jsonrpc: "2.0", method: "evm_snapshot", params: [], id: 0},
        function (error, result) {
            if (error) {
                reject(error);
            } else {
                resolve(result);
            }
        }
    );
});
const revert = (id) => new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync(
        {jsonrpc: "2.0", method: "evm_revert", params: [id], id: 0},
        function (error, result) {
            if (error) {
                reject(error);
            } else {
                resolve(result);
            }
        }
    );
});
function makePseudoAdress() {
    var text = "";
    var possible = "abcdef0123456789";
    for (var i = 0; i < 40; i++)
        text += possible.charAt(Math.floor(Math.random() *
            possible.length));
    return "0x" + text;
}
const seconds = (amount) => amount;
const minutes = (amount) => amount * seconds(60);
const hours = (amount) => amount * minutes(60);
const days = (amount) => amount * hours(24);
const weeks = (amount) => amount * days(7);
const months = (amount) => amount * days(30);
const years = (amount) => amount * months(12);

contract("TimeLockStorage", accounts => {

    const [ firstAccount,
            secondAccount,
            thirdaccount,
            fourthaccount,
            fifthaccount,
            firstOwner,
            secondOwner,
            thirdOwner,
            fourthOwner,
            fifthOwner] = accounts;

    let daoToken;
    let lockStorage;
    let snapshotId;

    beforeEach(async () => {
        daoToken = await QDAO.new(firstOwner, secondOwner, thirdOwner, fourthOwner, fifthOwner);
        lockStorage = await  TokenLocker.new(daoToken.address);

        await daoToken.addAddressToGovernanceContract(firstOwner, {from: firstOwner});
        await daoToken.addAddressToGovernanceContract(firstOwner, {from: firstAccount});
        await daoToken.addAddressToGovernanceContract(firstOwner, {from: thirdOwner});
        await daoToken.addAddressToGovernanceContract(firstOwner, {from: fourthOwner});

        await daoToken.mint(firstAccount, 1000*TOKEN, {from: firstOwner});

        await daoToken.addAddressToGovernanceContract(lockStorage.address, {from: firstOwner});
        await daoToken.addAddressToGovernanceContract(lockStorage.address, {from: firstAccount});
        await daoToken.addAddressToGovernanceContract(lockStorage.address, {from: thirdOwner});
        await daoToken.addAddressToGovernanceContract(lockStorage.address, {from: fourthOwner});
        snapshotId = (await snapshot()).result;
    });

    afterEach(async () => {
        await revert(snapshotId);
    });

    it("#1 should initialize correctly", async () => {
        assert.equal(await daoToken.symbol.call(), "QDAO");
        assert.equal(await daoToken.name.call(), "Q DAO Governance token v1.0");
        assert.equal(await daoToken.totalSupply.call(), 1000*TOKEN);
        assert.equal(await daoToken.balanceOf.call(firstAccount), 1000*TOKEN);

        assert.equal(web3.toBigNumber(await lockStorage.lostTime.call()).toString(), 7862400);
        assert.equal(web3.toBigNumber(await lockStorage.maximumDurationToFreeze.call()).toString(), 94694400);

        assert.equal(await lockStorage.totalLockedTokens.call(), 0);
        assert.equal(await lockStorage.withdrawableTokens.call(), 0);
        assert.equal(await lockStorage.owner.call(), firstAccount);

        assert.equal(await daoToken.balanceOf.call(lockStorage.address), 0);
        assert.equal(await lockStorage.token_.call(), daoToken.address);
    });

    it("#2 should be created simple lock storage", async () => {
        await lockStorage.createLockSlot(secondAccount, [20*TOKEN], [3600], {from: firstAccount});
        assert.equal(web3.toBigNumber(await lockStorage.lostTime.call()).toString(), 7862400);
        assert.equal(await lockStorage.withdrawableTokens.call(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 20*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 20*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(firstAccount)).toString(), 980*TOKEN);
        assert.equal(await lockStorage.getAddressToId(0), secondAccount);

        assert.equal(web3.toBigNumber(await lockStorage.getHoldersQuantity()).toString(), 1);
        assert.equal(web3.toBigNumber(await lockStorage.getSlotsQuantity()).toString(), 1);
    });

    it("#3 should be revert after non owner's call and incorrect params", async () => {

        try { // non owner
            await lockStorage.createLockSlot(secondAccount, [60*TOKEN], [3600], {from: secondOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        await lockStorage.createLockSlot(secondAccount, [20*TOKEN], [3600], {from: firstAccount});
        await lockStorage.createLockSlot(secondAccount, [50*TOKEN], [3600], {from: firstAccount});

        assert.equal(await lockStorage.getAddressToId(0), secondAccount);
        assert.equal(await lockStorage.getAddressToId(1), secondAccount);

        try { // LockStorage cannot be created for this address
            await lockStorage.createLockSlot(ZERO_ADDRESS, [20*TOKEN], [3600], {from: firstAccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }


        try { // Amount cannot be 0
          await lockStorage.createLockSlot(fifthaccount, [0], [3600], {from: firstAccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        await lockStorage.createLockSlot(fifthaccount, [20*TOKEN], [3600], {from: firstAccount});
        assert.equal(await lockStorage.getAddressToId(2), fifthaccount);

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 90*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 90*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(firstAccount)).toString(), 910*TOKEN);

        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 0);
        assert.equal(await lockStorage.getTotalLockedTokens(), 90*TOKEN);

        assert.equal(web3.toBigNumber(await lockStorage.getHoldersQuantity()).toString(), 2);
        assert.equal(web3.toBigNumber(await lockStorage.getSlotsQuantity()).toString(), 3);
    });

    it("#4 should be wihdraw from simple lockStorage", async () => {
        await lockStorage.createLockSlot(thirdaccount, [55*TOKEN], [3600], {from: firstAccount});

        try { // this lockStorage is not exists
            await lockStorage.release(0, {from: thirdOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 55*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 55*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(firstAccount)).toString(), 945*TOKEN);

        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 0);
        assert.equal(await lockStorage.getTotalLockedTokens(), 55*TOKEN);

        try { // Unlock time has not come
            await lockStorage.release(0, {from: thirdaccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        await increaseTime(hours(2));

        try { // This lockStorage is not exists
            await lockStorage.release(1, {from: fifthOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(0)).toString(), 55*TOKEN);
        await lockStorage.getAvailableTokens(0);

        await lockStorage.release(0, {from: thirdaccount});

        try { // Full withdraw already exists
            await lockStorage.release(0, {from: thirdaccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 55*TOKEN);

        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 0);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(thirdaccount)).toString(), 55*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(firstAccount)).toString(), 945*TOKEN);

        assert.equal(web3.toBigNumber(await lockStorage.lostTime.call()).toString(), 7862400);
        assert.equal(web3.toBigNumber(await lockStorage.maximumDurationToFreeze.call()).toString(), 94694400);

        assert.equal(await lockStorage.owner.call(), firstAccount);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(0)).toString(), 0);


        assert.equal(web3.toBigNumber(await lockStorage.getHoldersQuantity()).toString(), 1);
        assert.equal(web3.toBigNumber(await lockStorage.getSlotsQuantity()).toString(), 1);
    });

    it("#5 can't send ETHER", async () => {
        try { // Full withdraw already exists
            await lockStorage.sendTransaction({from: fourthaccount, value: 10 * ETHER});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        assert.equal(web3.eth.getBalance(lockStorage.address), 0);
    });

    it("#6 should be wihdraw from smart lockStorage from schedule", async () => {
        // ********************  lock
        await lockStorage.createLockSlot(secondAccount,
                                        [30*TOKEN, 5*TOKEN, 5*TOKEN, 5*TOKEN, 5*TOKEN, 5*TOKEN, 5*TOKEN],
                                        [86300, 7200, 7200, 7200, 7200, 7200, 7200] , {from: firstAccount}); // 1 day + 2 hours     30/5

        await lockStorage.createLockSlot( thirdaccount,
                                          [40*TOKEN, 12*TOKEN, 12*TOKEN, 12*TOKEN, 12*TOKEN, 12*TOKEN],
                                          [172700, 3600, 3600, 3600, 3600, 3600], {from: firstAccount}); // 2 days + 1 hour     40/12

        await lockStorage.createLockSlot( fourthaccount,
                                          [54*TOKEN, 63*TOKEN, 63*TOKEN],
                                          [2592000, 86400, 86400], {from: firstAccount}); // 1 mouth + 1 day     54/63

        await lockStorage.createLockSlot( fifthaccount,
                                          [30*TOKEN, 90*TOKEN, 90*TOKEN, 90*TOKEN],
                                          [7776000, 538800, 538800, 538800], {from: firstAccount}); // 3 mouths + 1 week  30/90

        await lockStorage.createLockSlot( secondOwner,
                                          [140*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN],
                                          [31536000, 2592000, 2592000, 2592000, 2592000 ,2592000, 2592000], {from: firstAccount}); // 1 year + 1 mouth   140/10

        await lockStorage.createLockSlot( thirdOwner,
                                          [70*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN],
                                          [63072000, 2592000, 2592000, 2592000, 2592000, 2592000, 2592000, 2592000], {from: firstAccount}); // 2 years + 1 mouth  70/10

        assert.equal(await lockStorage.getAddressToId(0), secondAccount);
        assert.equal(await lockStorage.getAddressToId(1), thirdaccount);
        assert.equal(await lockStorage.getAddressToId(2), fourthaccount);
        assert.equal(await lockStorage.getAddressToId(3), fifthaccount);
        assert.equal(await lockStorage.getAddressToId(4), secondOwner);
        assert.equal(await lockStorage.getAddressToId(5), thirdOwner);

        assert.equal(web3.toBigNumber(await lockStorage.getHoldersQuantity()).toString(), 6);
        assert.equal(web3.toBigNumber(await lockStorage.getSlotsQuantity()).toString(), 6);

        try { // Incorrect time, should be less 3 years
            await lockStorage.createLockSlot( fifthOwner,
                                              [70*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN, 10*TOKEN],
                                              [630720000, 2592000, 2592000, 2592000, 2592000, 2592000, 2592000, 2592000], {from: firstAccount}); // 2 years + 1 mouth  70/10
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 980*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 0);

        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 980*TOKEN);

        // ******************** balance before unlock
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(firstAccount)).toString(), 20*TOKEN);

        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(secondAccount)).toString(), 0);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(thirdaccount)).toString(), 0);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(fourthaccount)).toString(), 0);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(fifthaccount)).toString(), 0);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(secondOwner)).toString(), 0);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(thirdOwner)).toString(), 0);

        // ******************** after 1 day + 10 min
        await increaseTime(days(1));
        await increaseTime(minutes(10));

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(0)).toString(), 30*TOKEN); // 30
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(1)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(2)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(3)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(4)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(5)).toString(), 0);

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 980*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 0);

        await lockStorage.release(0, {from: secondAccount});

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 950*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 30*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(secondAccount)).toString(), 30*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 950*TOKEN);

        // ******************** after 2 day + 2 hours
        await increaseTime(days(1));
        await increaseTime(hours(2));

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(0)).toString(), 30*TOKEN);// 30+5+5+5+5+5+5
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(1)).toString(), 64*TOKEN); // 40+12+12

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(2)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(3)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(4)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(5)).toString(), 0);

        await lockStorage.release(0, {from: secondAccount});
        await lockStorage.release(1, {from: thirdaccount});

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(0)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(1)).toString(), 0);

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 856*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 124*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(secondAccount)).toString(), 60*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(thirdaccount)).toString(), 64*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 856*TOKEN);


        // ******************** after 3 day + 2 hours
        await increaseTime(days(1));

        try {
            await lockStorage.release(0, {from: secondAccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        try {
            await lockStorage.release(2, {from: fourthaccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        try {
            await lockStorage.release(3, {from: fifthaccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        try {
            await lockStorage.release(4, {from: secondOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        try {
            await lockStorage.release(5, {from: thirdOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        // ******************** after 3 months + 1 weeks  + 3 day + 2 hours + 10 min
        await increaseTime(months(3));
        await increaseTime(weeks(1));

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(1)).toString(), 36*TOKEN); // 12+12+12
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(2)).toString(), 180*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(3)).toString(), 120*TOKEN); // 30+90

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 856*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 124*TOKEN); //60+64
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 856*TOKEN);

        await lockStorage.release(1, {from: thirdaccount}); //36
        await lockStorage.release(2, {from: fourthaccount}); // 180
        await lockStorage.release(3, {from: fifthaccount}); // 120

        try { // release already
            await lockStorage.release(1, {from: thirdaccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        try { // release already
            await lockStorage.release(2, {from: fourthaccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 520*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 460*TOKEN);

        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(thirdaccount)).toString(), 100*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(fourthaccount)).toString(), 180*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(fifthaccount)).toString(), 120*TOKEN);

        try { // not time to lock
            await lockStorage.release(0, {from: secondOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        try {  // not time to lock
            await lockStorage.release(1, {from: thirdOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        // ******************** after 1 years + 4 months + 1 weeks  + 3 day + 2 hours + 10 min
        await increaseTime(years(1));
        await increaseTime(months(1));

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(4)).toString(), 180*TOKEN); // 140+10+10+10+10
        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 520*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 460*TOKEN);

        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 520*TOKEN);

        // ******************** after 2 years + 4 months + 1 weeks  + 3 day + 2 hours + 10 min
        await increaseTime(years(1));
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(4)).toString(), 200*TOKEN); //140+10+10+10+10+10+10
        await lockStorage.release(4, {from: secondOwner});

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(5)).toString(), 110*TOKEN); // 70+10+10+10+10

        await lockStorage.release(5, {from: thirdOwner});

        assert.equal(web3.toBigNumber(await lockStorage.totalLockedTokens.call()).toString(), 210*TOKEN);
        assert.equal(web3.toBigNumber(await lockStorage.getWithdrawableTokens()).toString(), 770*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 210*TOKEN);

        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(secondOwner)).toString(), 200*TOKEN);
        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(thirdOwner)).toString(), 110*TOKEN);

        // ******************** after 3 years + 4 months + 1 weeks  + 3 day + 2 hours + 10 min
        await increaseTime(years(1));

        await lockStorage.withdrawLostToken(3, {from: firstAccount});
        await lockStorage.withdrawLostToken(5, {from: firstAccount});

        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(3)).toString(), 0);
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(5)).toString(), 0);
    });

    it("#7 withdraw lost tokens", async () => {
        await lockStorage.createLockSlot(fifthOwner, [20*TOKEN], [3600], {from: firstAccount});

        try { // tokens are not lost
            await lockStorage.withdrawLostToken(0, {from: firstAccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        await increaseTime(months(2));

        try { // tokens are not lost
            await lockStorage.withdrawLostToken(0, {from: firstAccount});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        await increaseTime(hours(3));
        await increaseTime(months(2));

        assert.equal(web3.toBigNumber(await daoToken.balanceOf.call(lockStorage.address)).toString(), 20*TOKEN);

        try { // not ownable contract
            await lockStorage.withdrawLostToken(0, {from: secondOwner});
            assert.fail();
        } catch (err) {
            assert.ok(/revert/.test(err.message));
        }

        await increaseTime(months(2));

        await lockStorage.withdrawLostToken(0, {from: firstAccount});
        assert.equal(web3.toBigNumber(await lockStorage.getAvailableTokens(0)).toString(), 0);
    });
});

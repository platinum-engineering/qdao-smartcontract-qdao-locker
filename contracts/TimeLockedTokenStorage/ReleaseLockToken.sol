pragma solidity ^0.4.24;

import "./SafeStorage.sol";

contract ReleaseLockToken is SafeStorage {

    event TokensWithdrawed(address indexed sender, uint256 amount, uint256 time);

    uint256 public withdrawableTokens;

    /**
    * @dev Withdraw locked tokens
    * Usage of this method only holder this lockSlot's id
    * @param _lockSlotId uint256 unique id lockSlot
    */
    function release(uint256 _lockSlotId) public {
        require(_validateWithdraw(msg.sender, _lockSlotId));
        uint256 tokensForWithdraw = _getAvailableTokens(msg.sender, _lockSlotId);

        lockTokenStorage[msg.sender][_lockSlotId].paidTokens = lockTokenStorage[msg.sender][_lockSlotId].paidTokens.add(tokensForWithdraw);
        token_.transfer(msg.sender,  tokensForWithdraw);

        if(_combineArray(lockTokenStorage[msg.sender][_lockSlotId].tokens) == lockTokenStorage[msg.sender][_lockSlotId].paidTokens) {
            _finalizeLock(msg.sender, _lockSlotId);
        }

        withdrawableTokens = withdrawableTokens.add(tokensForWithdraw);
        totalLockedTokens = totalLockedTokens.sub(tokensForWithdraw);
        emit TokensWithdrawed(msg.sender, tokensForWithdraw, now);
    }

    /**
    * @dev Returned all withdrawn tokens
    */
    function getWithdrawableTokens() public view returns(uint256) {
        return withdrawableTokens;
    }

    /**
    * @dev Withdrawn lost tokens
    * Usage of this method only only owner
    * @param _lockSlotId uint256 unique id lockSlot
    */
    function withdrawLostToken(uint256 _lockSlotId) public onlyOwner {

        require(now > lostTime.add(
            lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods[lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods.length-1]),
            "Tokens are not lost");

        uint256 tokensForWithdraw = _getAvailableTokens(getAddressToId(_lockSlotId), _lockSlotId);
        withdrawableTokens = withdrawableTokens.add(tokensForWithdraw);
        totalLockedTokens = totalLockedTokens.sub(tokensForWithdraw);
        lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].paidTokens = _combineArray(lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].tokens);
        _finalizeLock(getAddressToId(_lockSlotId), _lockSlotId);
        token_.transfer( owner,  tokensForWithdraw);
    }

    /**
    * @dev Returned date and amount to counter
    * @param _lockSlotId uint256 unique id lockSlot
    * @param _i uint256 count number
    */
    function getDateAndReleaseToCounter(uint256 _lockSlotId,
                                        uint256 _i) public view returns(uint256 _nextDate,
                                                                        uint256 _nextRelease) {

        require( _i < lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods.length);

        _nextRelease = lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].tokens[_i];
        _nextDate = lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods[_i];
    }

    /**
    * @dev Returned nearest date for withdraw
    * @param _lockSlotId uint256 unique id lockSlot
    */
    function getNextDateWithdraw(uint256 _lockSlotId) public view returns(uint256) {
        uint256 nextDate;

        if(now > lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods[lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods.length-1]) {
            nextDate = 0;
        }
        else {
            for(uint256 i = 0; i < lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods.length; i++) {
                if(now < lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods[i]) {
                    nextDate = lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods[i];
                    break;
                }
            }
        }
        return nextDate;
    }

    function _finalizeLock(address _who, uint256 _id) internal {
        lockTokenStorage[_who][_id].finalized = true;
    }

    function _validateWithdraw(address _who, uint256 _id) internal view returns(bool) {
        require(!lockTokenStorage[_who][_id].finalized, "Full withdraw already exists");
        require(_combineArray(lockTokenStorage[_who][_id].tokens) > 0 , "This lockStorage is not exists");
        require(now > lockTokenStorage[_who][_id].periods[0], "Unlock time has not come");

        return true;
    }

    function _getAvailableTokens(address _who, uint256 _id) internal view returns(uint256) {
        uint256 tokensForWithdraw;

        uint256 paidTokens = lockTokenStorage[_who][_id].paidTokens;

        for(uint256 i = lockTokenStorage[_who][_id].periods.length-1; i >= 0; i--) {
            if(now >= lockTokenStorage[_who][_id].periods[i]) {

                for(uint256 y = 0; y < i+1; y++) {
                    tokensForWithdraw += lockTokenStorage[_who][_id].tokens[y];
                }
                tokensForWithdraw -= paidTokens;
                break;
            }
        }
        return tokensForWithdraw;
    }
}

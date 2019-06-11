pragma solidity ^0.4.24;

import "./ReleaseLockToken.sol";

contract TimeLockedTokenStorage is ReleaseLockToken {

    constructor(address _token) public {
        token_ = IQDAO(_token);
        lostTime = 7862400; // 3 months
        maximumDurationToFreeze = 94694400; // 3 years
    }


    /**
    * @dev Returned available tokens for withdraw
    * @param _lockSlotId uint256 unique id lockSlot
    */
    function getAvailableTokens(uint256 _lockSlotId) public view returns(uint256) {
        if (now < uint256(lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods[0])) {
            return 0;
        } else {
            return _getAvailableTokens(getAddressToId(_lockSlotId), _lockSlotId);
        }
    }

    /**
    * @dev Returned total holders
    */
    function getHoldersQuantity() public view returns(uint256) {
        return holdersList.length;
    }

    /**
   * @dev Returned total locked slots
   */
    function getSlotsQuantity() public view returns(uint256) {
        return totalSlot.length;
    }
    /**
     * @dev Returned total locked tokens
    */
    function getTotalLockedTokens() public view returns(uint256) {
        return totalLockedTokens;
    }
    /**
    * @dev Returned params for lockSlot
    * @param _lockSlotId uint256 unique id lockSlot
    */
    function getLock(uint256 _lockSlotId) public view returns(  uint256 _amountTokens,
                                                                uint256[] _periods,
                                                                uint256[] _tokens,
                                                                uint256 _paidTokens,
                                                                bool _finalize) {

        _amountTokens = _combineArray(lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].tokens);
        _periods = lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].periods;
        _tokens = lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].tokens;
        _paidTokens = lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].paidTokens;
        _finalize = lockTokenStorage[getAddressToId(_lockSlotId)][_lockSlotId].finalized;
    }
}

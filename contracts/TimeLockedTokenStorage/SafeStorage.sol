pragma solidity ^0.4.24;

import "../QDAO/IQDAO.sol";
import "openzeppelin-solidity/contracts/ownership/HasNoEther.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../Library/ArrayTools.sol";

/**
 * @title Base Safe Storage
 *
 * @dev Implementation of the storage to QDAO tokenTimeLocker.
 * https://github.com/platinum-engineering
 * https://github.com/OpenZeppelin/openzeppelin-solidity
 */
contract SafeStorage is HasNoEther, ArrayTools {
    using SafeMath for uint256;

    event LockSlotCreated(address indexed holder, uint256 id, uint256 amount);

    struct LockSlot{
        uint256[] tokens;
        uint256[] periods;
        uint256 paidTokens;
        bool finalized;
    }

    mapping (address => mapping(uint256 => LockSlot)) internal lockTokenStorage;

    mapping (address => uint256[]) private lockSlotIdList;

    address[] internal holdersList;

    address[] internal totalSlot;

    uint256 public maximumDurationToFreeze;

    uint256 public lostTime;

    uint256 public totalLockedTokens;

    IQDAO public token_;

    /**
    * @dev Create slot for holder
    * Usage of this method only only owner
    * @param _holder address The address which you want to lock tokens
    * @param _tokens uint256[]  the amount of tokens to be locked
    * @param _periods uint256[] the amount of periods to be locked
    */
    function createLockSlot(address _holder, uint256[] _tokens, uint256[] _periods) public onlyOwner {

        require(_holder != address(0), "LockStorage cannot be created for this address");
        require (_tokens.length == _periods.length && _tokens.length > 0);
        require(_combineArray(_periods) <= maximumDurationToFreeze, "Incorrect time, should be less 3 years");
        require(_combineArray(_tokens) > 0, "Incorrect amount");

        uint256 fullAmount = _combineArray(_tokens);
        uint256 newId = totalSlot.length;

        token_.approveForOtherContracts(msg.sender, this, fullAmount);
        token_.transferFrom(msg.sender, this, fullAmount);

        lockTokenStorage[_holder][newId] = _createLockSlot(_tokens, _periods);

        totalSlot.push(_holder);
        totalLockedTokens = totalLockedTokens.add(fullAmount);

        if(lockSlotIdList[_holder].length == 0) {
            holdersList.push(_holder);
        }

        lockSlotIdList[_holder].push(newId);

        emit LockSlotCreated(_holder, newId, fullAmount);
    }

    /**
    * @dev Returned holder's address
    * @param _lockSlotId uint256 unique id lockSlot
    */
    function getAddressToId(uint256 _lockSlotId) public view returns(address) {
        return totalSlot[_lockSlotId];
    }

    /**
    * @dev Returned all created unique ids
    * @param _holder address The holder's address
    */
    function getAllLockSlotIdsToAddress(address _holder) public view returns(uint256[] _lockSlotIds) {
        return lockSlotIdList[_holder];
    }

    function _createLockSlot(uint256[] _lockTokens, uint256[] _lockPeriods) internal view returns(LockSlot memory _lockSlot) {
        _lockPeriods[0] +=now;

        if (_lockPeriods.length > 1) {
            for(uint256 i = 1; i < _lockPeriods.length; i++) {
                _lockPeriods[i] += _lockPeriods[i-1];
            }
        }

        _lockSlot = LockSlot({
            tokens: _lockTokens,
            periods: _lockPeriods,
            paidTokens: 0,
            finalized: false
            });
    }
}

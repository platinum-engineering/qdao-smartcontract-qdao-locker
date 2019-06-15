pragma solidity ^0.4.24;

library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (_a == 0) {
            return 0;
        }

        c = _a * _b;
        assert(c / _a == _b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        // assert(_b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = _a / _b;
        // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
        return _a / _b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        assert(_b <= _a);
        return _a - _b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        c = _a + _b;
        assert(c >= _a);
        return c;
    }
}

contract ArrayTools {

    function _combineArray(uint256[] _array) internal pure returns(uint256) {
        uint256 fullAmount;
        for(uint256 i = 0; i < _array.length; i++) {
            require(_array[i] > 0);
            fullAmount += _array[i];
        }
        return fullAmount;
    }
}

contract IQDAO {
    function balanceOf(address _owner) public view returns (uint256);
    function approveForOtherContracts(address _sender, address _spender, uint256 _value) external;
    function transfer(address _to, uint256 _value) public returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
}

contract Ownable {
    address public owner;


    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );


    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        _transferOwnership(_newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address _newOwner) internal {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

contract WhitelistMigratable is Ownable {

    mapping(address => bool) public governanceContracts;

    event GovernanceContractAdded(address addr);
    event GovernanceContractRemoved(address addr);

    modifier onlyGovernanceContracts() {
        require(governanceContracts[msg.sender]);
        _;
    }


    function addAddressToGovernanceContract(address addr) onlyOwner public returns(bool success) {
        if (!governanceContracts[addr]) {
            governanceContracts[addr] = true;
            emit GovernanceContractAdded(addr);
            success = true;
        }
    }


    function removeAddressFromGovernanceContract(address addr) onlyOwner public returns(bool success) {
        if (governanceContracts[addr]) {
            governanceContracts[addr] = false;
            emit GovernanceContractRemoved(addr);
            success = true;
        }
    }
}

contract SafeStorage is WhitelistMigratable, ArrayTools {
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
    * Usage of this method only owner
    * @param _holder address The address which you want to lock tokens
    * @param _tokens uint256[]  the amount of tokens to be locked
    * @param _periods uint256[] the amount of periods to be locked
    */
    function createLockSlot(address _holder, uint256[] _tokens, uint256[] _periods) public onlyGovernanceContracts {

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
    * Usage of this method only owner
    * @param _lockSlotId uint256 unique id lockSlot
    */
    function withdrawLostToken(uint256 _lockSlotId) public onlyGovernanceContracts {

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

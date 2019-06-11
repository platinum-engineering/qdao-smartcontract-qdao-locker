pragma solidity ^0.4.24;

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

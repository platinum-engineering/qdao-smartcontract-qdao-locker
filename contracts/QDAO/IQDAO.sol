pragma solidity ^0.4.24;

contract IQDAO {
    function balanceOf(address _owner) public view returns (uint256);
    function approveForOtherContracts(address _sender, address _spender, uint256 _value) external;
    function transfer(address _to, uint256 _value) public returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
}

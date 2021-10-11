// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16 <0.9.0;

contract User {
    enum UserType { none, reader, reviewer, writer }
    
    // Maps user Ethereum addresses to internal IDs
    mapping (address => uint32) userId;
    // Maps user Ethereum addresses to accounts types
    mapping (address => UserType) userType;
 
    
    function updateUserId (uint32 id) public{
        userId[msg.sender] = id;
    }
    
    function retrieveUserId(address userAddress) public view returns (uint32) {
        return userId[userAddress];
    }
    
 
    
    function updateUserType(UserType newType) public {
        userType[msg.sender] = newType;
    }
    
    function retrieveUserType(address userAddress) public view returns (UserType) {
        return userType[userAddress];
    }
}
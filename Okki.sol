pragma solidity ^0.4.19;

/******************************************************************************************
 *
 *   Author: David Wong
 *
 *   Description: This is a multi-signature wallet that supports ethers and any ERC-20 token.
 *     This contract aims to be extremly simple. Why? Because it stores your money.
 *     No more than 8 owners are allowed.
 *     What if you need a change of owner? re-create a contract and transfer the funds there.
 *     What if you need a change of threshold? re-create a contract and transfer the funds there.
 *     That's it.
 *   
 *   Contact: https://www.cryptologie.net/contact
 *
 *******************************************************************************************/

interface erc20token {
    function transfer(address to, uint tokens) external returns (bool success);
}

contract Okki {
    
    // structures
    
    address[] public owners;
    uint8 public threshold;
    
    struct transaction {
        address to;
        uint256 amount;
        address tokenContract;
        address[] confirmations;
        bool executed;
    }
    transaction[] public transactions;
    
    // modifiers
    
    modifier onlyOwners() {
        bool found = false;
        for (uint8 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                found = true;
                break;
            }
        }
        require(found);
        _;
    }
    
    // constructor
    
    function Okki(address[] _owners, uint8 _threshold) public {
        require(_owners.length <= 10);
        require(_threshold <= _owners.length);
        owners = _owners;
        threshold = _threshold;
    }

    // ether transaction functions

    function initiateTransaction(address _to, uint256 _amount, address _tokenContract) onlyOwners public returns (uint256) {
        return transactions.push(transaction(_to, _amount, _tokenContract, new address[](0), false)) - 1;
    }
    
    function confirmTransaction(uint256 _transactionId) onlyOwners public returns (bool) {
        address[] memory confirmations = transactions[_transactionId].confirmations;
        for (uint8 i = 0; i < confirmations.length; i++) {
            if (confirmations[i] == msg.sender) 
                return false;
        }
        transactions[_transactionId].confirmations.push(msg.sender);
        return tryToExecuteTransaction(_transactionId);
    }
    
    function revokeTransaction(uint256 _transactionId) onlyOwners public {
        address[] memory confirmations = transactions[_transactionId].confirmations;
        bool found;
        uint8 i;
        for (i = 0; i < confirmations.length; i++) {
            if (confirmations[i] == msg.sender) {
                found = true;
                break;
            }
        }
        require(found);
        delete transactions[_transactionId].confirmations[i];
    }
    
    function tryToExecuteTransaction(uint256 _transactionId) private returns (bool) {
        transaction memory fetchedTransaction = transactions[_transactionId];
        require(!fetchedTransaction.executed);
        if (fetchedTransaction.confirmations.length < threshold) {
            return false;
        }
        // ether transfer
        if (fetchedTransaction.tokenContract == 0x0) {
            fetchedTransaction.to.transfer(fetchedTransaction.amount);
        } 
        // erc-20 token transfer
        else {
            erc20token token = erc20token(fetchedTransaction.tokenContract);
            require(token.transfer(fetchedTransaction.to, fetchedTransaction.amount));
        }
        fetchedTransaction.executed = true;
        return true;
    }
}

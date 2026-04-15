// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "./../src/contracts/Vault.sol";

contract TestVault is Test {
    Vault vault;

    function setUp() public {
        vault = new Vault();
    }

    function test_add_contact() external {
        string memory firstname = "John";
        string memory lastname = "Doe";
        string memory email = "johndoe@email.com";
        string memory phone = "0152525656";
        string memory category = "Friends";

        vm.expectEmit(true, true, false, true);
        emit Vault.ContactAdded(
            1,
            firstname,
            lastname,
            email,
            phone,
            category,
            ""
        );

        vault.addContact(firstname, lastname, email, phone, category, "");
    }
}

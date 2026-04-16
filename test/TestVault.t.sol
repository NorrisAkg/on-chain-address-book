// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault, Vault__Missing_required_infos, Vault__Max_contacts_reached, Vault__Contact_not_exists} from "./../src/contracts/Vault.sol";

contract TestVault is Test {
    Vault vault;

    function setUp() public {
        vault = new Vault();
    }

    function createContact() private returns (Vault.Contact memory) {
        string memory firstname = "John";
        string memory lastname = "Doe";
        string memory email = "johndoe@email.com";
        string memory phone = "0152525656";
        string memory category = "Friends";
        string memory physicalAddress = "Paris";

        return
            vault.addContact(
                firstname,
                lastname,
                email,
                phone,
                category,
                physicalAddress
            );
    }

    function test_add_contact() external {
        vm.expectEmit(true, true, false, true);
        emit Vault.ContactAdded(
            1,
            "John",
            "Doe",
            "johndoe@email.com",
            "0152525656",
            "Friends",
            "Paris"
        );
        createContact();
    }

    function test_add_contact_fails_without_required_entries() external {
        string memory firstname = "John";
        string memory lastname = "";
        string memory email = "johndoe@email.com";
        string memory phone = "0152525656";
        string memory category = "Friends";
        string memory physicalAddress = "";

        vm.expectRevert(
            abi.encodeWithSelector(Vault__Missing_required_infos.selector)
        );
        vault.addContact(
            firstname,
            lastname,
            email,
            phone,
            category,
            physicalAddress
        );
    }

    function test_update_contact() external {
        Vault.Contact memory contact = createContact();

        // console.log("contact id", contact.id);

        string memory newFistname = "Bob";
        string memory newEmail = "bob@email.com";

        vm.expectEmit(true, true, false, true);
        emit Vault.ContactUpdated(
            1,
            newFistname,
            contact.lastname,
            newEmail,
            contact.phone,
            contact.physicalAddress,
            contact.category
        );

        Vault.Contact memory contactUpdated = vault.updateContact(
            contact.id,
            newFistname,
            "",
            newEmail,
            "",
            "",
            ""
        );

        assertEq(contactUpdated.firstname, newFistname);
        assertEq(contactUpdated.email, newEmail);
    }
}

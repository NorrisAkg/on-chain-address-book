// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault, Vault__Missing_required_infos, Vault__Max_contacts_reached, Vault__Contact_not_exists, Vault__Not_the_contact_owner, Vault__Contact_already_exists} from "./../src/contracts/Vault.sol";

contract TestVault is Test {
    Vault vault;
    address bob = makeAddr("Bob");
    address alice = makeAddr("Alice");

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

    function test_add_many_contacts() external {
        vm.startPrank(alice);
        Vault.Contact memory contact = createContact();

        Vault.Contact memory contact2 = vault.addContact(
            "Jane",
            "Doe",
            "jane@email.com",
            "0154545454",
            "Family",
            "Paris"
        );

        assertEq(contact.id, 1);
        assertEq(contact2.id, 2);
        assertEq(vault.getContactOwner(contact.id), alice);
        assertEq(vault.getContactOwner(contact2.id), alice);
        assertEq(vault.getContacts().length, 2);

        vm.stopPrank();
    }

    function test_add_contact_fails_if_already_exists() external {
        vm.startPrank(alice);
        Vault.Contact memory contact = createContact();

        vm.expectRevert(
            abi.encodeWithSelector(
                Vault__Contact_already_exists.selector,
                contact.firstname,
                contact.lastname
            )
        );
        Vault.Contact memory contact2 = vault.addContact(
            "John",
            "Doe",
            "jane@email.com",
            "0154545454",
            "Family",
            "Paris"
        );

        assertEq(contact.id, 1);
        assertEq(contact2.id, 2);
        assertEq(vault.getContactOwner(contact.id), alice);
        assertEq(vault.getContactOwner(contact2.id), alice);
        assertEq(vault.getContacts().length, 2);

        vm.stopPrank();
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

    function test_update_fails_if_contact_not_exists() external {
        uint256 contactId = 2;

        vm.expectRevert(
            abi.encodeWithSelector(
                Vault__Contact_not_exists.selector,
                contactId
            )
        );
        vault.updateContact(2, "John", "Doe", "", "", "", "");
    }

    function test_update_fails_if_not_contact_owner() external {
        vm.prank(bob);
        Vault.Contact memory contact = createContact();

        vm.expectRevert(
            abi.encodeWithSelector(Vault__Not_the_contact_owner.selector)
        );
        vm.prank(alice);
        vault.updateContact(contact.id, "John", "Doe", "", "", "", "");
    }

    function test_delete_contact() external {
        vm.startPrank(alice);
        Vault.Contact memory contact = createContact();

        uint256 contactId = contact.id;

        assertEq(vault.checkContactExisting(contact.id), true);

        vault.deleteContact(contactId);

        assertEq(vault.checkContactExisting(contactId), false);
        vm.stopPrank();
    }

    function test_delete_fails_if_not_contact_owner() external {
        vm.prank(bob);
        Vault.Contact memory contact = createContact();
        uint256 contactId = contact.id;

        vm.expectRevert(
            abi.encodeWithSelector(Vault__Not_the_contact_owner.selector)
        );
        vm.prank(alice);
        vault.deleteContact(contactId);
    }
}

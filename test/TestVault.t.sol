// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "./../src/contracts/Vault.sol";

contract TestVault is Test, Vault {
    Vault vault;
    address bob = makeAddr("Bob");
    address alice = makeAddr("Alice");

    function setUp() public {
        vault = new Vault();
    }

    function createContact() private returns (Vault.Contact memory) {
        ContactInput memory input = ContactInput({
            firstname: "John",
            lastname: "Doe",
            email: "johndoe@email.com",
            phone: "0152525656",
            physicalAddress: "Paris",
            category: Category.Friend
        });

        return vault.addContact(input);
    }

    function test_add_contact() external {
        vm.expectEmit(true, true, false, true);
        emit Vault.ContactAdded(
            1,
            "John",
            "Doe",
            "johndoe@email.com",
            "0152525656",
            Category.Friend,
            "Paris"
        );
        createContact();
    }

    function test_add_many_contacts() external {
        vm.startPrank(alice);
        Vault.Contact memory contact = createContact();

        Vault.Contact memory contact2 = vault.addContact(
            ContactInput({
                firstname: "Jane",
                lastname: "Doe",
                email: "jane@email.com",
                phone: "0154545454",
                physicalAddress: "Paris",
                category: Category.Family
            })
        );

        assertEq(contact.id, 1);
        assertEq(contact2.id, 2);
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
        vault.addContact(
            ContactInput({
                firstname: "John",
                lastname: "Doe",
                email: "jane@email.com",
                phone: "0154545454",
                physicalAddress: "Paris",
                category: Category.Family
            })
        );

        vm.stopPrank();
    }

    function test_add_contact_fails_without_required_entries() external {
        ContactInput memory input = ContactInput({
            firstname: "John",
            lastname: "",
            email: "johndoe@email.com",
            phone: "0152525656",
            physicalAddress: "",
            category: Category.Friend
        });

        vm.expectRevert(
            abi.encodeWithSelector(Vault__Missing_required_infos.selector)
        );
        vault.addContact(input);
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
            Category.None
        );

        assertEq(contactUpdated.firstname, newFistname);
        assertEq(contactUpdated.email, newEmail);
    }

    function test_update_fails_if_contact_not_exists() external {
        uint256 contactId = 2;

        vm.expectRevert(
            abi.encodeWithSelector(
                Vault__Not_the_contact_owner.selector,
                contactId
            )
        );
        vault.updateContact(2, "John", "Doe", "", "", "", Category.None);
    }

    function test_update_fails_if_not_contact_owner() external {
        vm.prank(bob);
        Vault.Contact memory contact = createContact();

        vm.expectRevert(
            abi.encodeWithSelector(Vault__Not_the_contact_owner.selector)
        );
        vm.prank(alice);
        vault.updateContact(
            contact.id,
            "John",
            "Doe",
            "",
            "",
            "",
            Category.None
        );
    }

    function test_delete_contact() external {
        vm.startPrank(alice);
        Vault.Contact memory contact = createContact();

        uint256 contactId = contact.id;

        vault.deleteContact(contactId);

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

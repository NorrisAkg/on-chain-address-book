// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Vault__Not_the_owner();

contract Vault {
    event contactAdded(
        string indexed firstname,
        string indexed lastname,
        string indexed email,
        string phone,
        string physicalAddress,
        string category
    );

    uint256 constant MAXIMUM_CONTACTS_PER_USER = 500;
    uint256 constant MAXIMUM_CATEGORIES_PER_USER = 10;

    struct Contact {
        string firstname;
        string lastname;
        string email;
        string phone;
        string physicalAddress;
        string category;
    }

    mapping(address user => string[MAXIMUM_CATEGORIES_PER_USER] category) userCustomCategories;
    mapping(address user => Contact[MAXIMUM_CONTACTS_PER_USER] contacts) userContacts;

    function addCategory() public {}

    function addContact(
        string memory _firstname,
        string memory _lastname,
        string memory _email,
        string memory _phone,
        string memory _physicalAddress,
        string memory _category
    ) public {
        Contact memory contact = Contact({
            firstname: _firstname,
            lastname: _lastname,
            email: _email,
            phone: _phone,
            physicalAddress: _physicalAddress,
            category: _category
        });

        Contact[500] storage contacts = userContacts[msg.sender];

        if (contacts.length < MAXIMUM_CONTACTS_PER_USER) {
            uint256 contactIndex = contacts.length;
            contacts[contactIndex] = contact;
        }

        emit contactAdded(
            _firstname,
            _lastname,
            _email,
            _phone,
            _physicalAddress,
            _category
        );
    }
}

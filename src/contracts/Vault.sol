// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/Test.sol";

error Vault__Not_the_owner();
error Vault__Not_the_contact_owner();
error Vault__Max_contacts_reached();
error Vault__Missing_required_infos();
error Vault__Contact_not_exists(uint256 _contactId);
error Vault__Contact_already_exists(string firstname, string lastname);

contract Vault {
    event ContactAdded(
        uint256 indexed id,
        string indexed firstname,
        string indexed lastname,
        string email,
        string phone,
        string category,
        string physicalAddress
    );

    event ContactUpdated(
        uint256 id,
        string indexed firstname,
        string indexed lastname,
        string email,
        string phone,
        string physicalAddress,
        string category
    );

    event ContactDeleted(uint256 id);

    address private immutable OWNER;
    uint256 constant MAX_CONTACTS_PER_USER = 500;
    uint256 constant MAX_CATEGORIES_PER_USER = 10;

    struct Contact {
        uint256 id;
        string firstname;
        string lastname;
        string email;
        string phone;
        string physicalAddress;
        string category;
    }

    uint256 lastIndex = 0;
    mapping(address user => Contact[] contacts) internal userContacts;
    mapping(address user => mapping(uint256 id => uint256 index))
        internal userContactToIndex;
    mapping(uint256 contactId => bool existing) internal contactExisting;
    mapping(address user => mapping(string fullname => bool existing))
        internal userContactFullnameExisting;
    mapping(uint256 contactId => address contactOwner) contactIdToOwner;
    mapping(address user => mapping(string category => uint256[] contactsIds))
        internal userContactsByCategory;

    constructor() {
        OWNER = msg.sender;
    }

    function addCategory() public onlyOwner {}

    function addContact(
        string memory _firstname,
        string memory _lastname,
        string memory _email,
        string memory _phone,
        string memory _category,
        string memory _physicalAddress
    )
        public
        requireLastNameAndFirstname(_firstname, _lastname)
        checkContactDuplicating(_firstname, _lastname)
        returns (Contact memory)
    {
        Contact[] storage contacts = userContacts[msg.sender];
        uint256 contactsLength = contacts.length;
        if (contactsLength == MAX_CONTACTS_PER_USER) {
            revert Vault__Max_contacts_reached();
        }

        uint256 newContactId = ++lastIndex;

        Contact memory contact = Contact({
            id: newContactId,
            firstname: _firstname,
            lastname: _lastname,
            email: _email,
            phone: _phone,
            physicalAddress: _physicalAddress,
            category: _category
        });

        contacts.push(contact);
        userContactToIndex[msg.sender][newContactId] = contactsLength;
        contactExisting[newContactId] = true;
        contactIdToOwner[newContactId] = msg.sender;
        userContactFullnameExisting[msg.sender][
            computeFullname(_firstname, _lastname)
        ] = true;
        userContactsByCategory[msg.sender][_category].push(newContactId);

        emit ContactAdded(
            newContactId,
            _firstname,
            _lastname,
            _email,
            _phone,
            _category,
            _physicalAddress
        );

        // unchecked {
        //     lastIndex++;
        // }

        return contact;
    }

    function updateContact(
        uint256 _contactId,
        string memory _firstname,
        string memory _lastname,
        string memory _email,
        string memory _phone,
        string memory _physicalAddress,
        string memory _category
    )
        public
        contactExists(_contactId)
        onlyContactOwner(_contactId)
        returns (Contact memory)
    {
        address msgSender = msg.sender;
        uint256 contactIndex = userContactToIndex[msgSender][_contactId];
        Contact memory contact = userContacts[msgSender][contactIndex];
        string memory oldFirstname = contact.firstname;
        string memory oldLastname = contact.lastname;
        string memory oldCategory = contact.category;
        string memory updatedFirstname = isStrEmpty(_firstname)
            ? oldFirstname
            : _firstname;
        string memory updatedLastname = isStrEmpty(_lastname)
            ? oldLastname
            : _lastname;
        string memory updatedCategory = isStrEmpty(_category)
            ? oldCategory
            : _category;

        uint256[] storage oldCategoryContactsIds = userContactsByCategory[
            msgSender
        ][oldCategory];
        uint256 oldCategotyIdsLength = oldCategoryContactsIds.length;

        bool firstnameChanged = !isStrEmpty(_firstname) &&
            !compareStrings(_firstname, oldFirstname);
        bool lastnameChanged = !isStrEmpty(_lastname) &&
            !compareStrings(_lastname, oldLastname);
        bool categoryChanged = !isStrEmpty(_category) &&
            !compareStrings(_category, oldCategory);

        if (firstnameChanged || lastnameChanged) {
            string memory newFullname = computeFullname(
                updatedFirstname,
                updatedLastname
            );
            string memory oldFullname = computeFullname(
                oldFirstname,
                oldLastname
            );

            if (userContactFullnameExisting[msgSender][newFullname]) {
                revert Vault__Contact_already_exists(
                    updatedFirstname,
                    updatedLastname
                );
            }

            userContactFullnameExisting[msgSender][oldFullname] = false;
            userContactFullnameExisting[msgSender][newFullname] = true;
        }

        if (categoryChanged) {
            for (uint256 i; i < oldCategotyIdsLength; ) {
                if (oldCategoryContactsIds[i] == _contactId) {
                    oldCategoryContactsIds[i] = oldCategoryContactsIds[
                        oldCategotyIdsLength - 1
                    ];
                    oldCategoryContactsIds.pop();
                }

                unchecked {
                    ++i;
                }
            }
        }

        contact.firstname = updatedFirstname;
        contact.lastname = updatedLastname;
        contact.email = isStrEmpty(_email) ? contact.email : _email;
        contact.phone = isStrEmpty(_phone) ? contact.phone : _phone;
        contact.category = updatedCategory;
        contact.physicalAddress = isStrEmpty(_physicalAddress)
            ? contact.physicalAddress
            : _physicalAddress;

        userContacts[msgSender][contactIndex] = contact;

        emit ContactUpdated(
            contact.id,
            contact.firstname,
            contact.lastname,
            contact.email,
            contact.phone,
            contact.physicalAddress,
            contact.category
        );

        return contact;
    }

    function deleteContact(
        uint256 _contactId
    ) public contactExists(_contactId) onlyContactOwner(_contactId) {
        uint256 contactIndex = userContactToIndex[msg.sender][_contactId]; // Get contact index

        Contact[] storage contacts = userContacts[msg.sender]; // get user contacts
        uint256 contactsLength = contacts.length;

        Contact memory contact = contacts[contactIndex];

        uint256[] storage contactCategoryContactsIds = userContactsByCategory[
            msg.sender
        ][contact.category];
        uint256 contactIdsLength = contactCategoryContactsIds.length;

        uint256 latestContactId = contacts[contactsLength - 1].id; // Get the latest contact id to update his index in array later

        userContactToIndex[msg.sender][latestContactId] = contactIndex; // update index of the element moved

        contactExisting[_contactId] = false; // set contact existing to false

        userContactFullnameExisting[msg.sender][
            computeFullname(contact.firstname, contact.lastname)
        ] = false;

        contacts[contactIndex] = contacts[contacts.length - 1]; // replace value at the contactIndex by the latest value in the array
        contacts.pop(); // delete latest element

        for (uint256 i; i < contactIdsLength; ) {
            if (contactCategoryContactsIds[i] == _contactId) {
                contactCategoryContactsIds[i] = contactCategoryContactsIds[
                    contactIdsLength - 1
                ];
                contactCategoryContactsIds.pop();
            }

            unchecked {
                ++i;
            }
        }

        emit ContactDeleted(_contactId);
    }

    function filterContactsByCategory(
        string memory _category
    ) public view returns (Contact[] memory) {
        uint256[] memory contactsIds = userContactsByCategory[msg.sender][
            _category
        ]; // Get contacts ids for the given category
        uint256 contactsIdLength = contactsIds.length;

        Contact[] memory _userContacts = userContacts[msg.sender];

        Contact[] memory resultContacts = new Contact[](contactsIdLength);

        for (uint256 i = 0; i < contactsIdLength; ) {
            uint256 contactIndex = userContactToIndex[msg.sender][
                contactsIds[i]
            ]; // get the contact index

            Contact memory contact = _userContacts[contactIndex]; // Get the contact

            resultContacts[i] = contact; // push contact into contacts array

            unchecked {
                ++i;
            }
        }

        return resultContacts;
    }

    modifier requireLastNameAndFirstname(
        string memory _firstname,
        string memory _lastname
    ) {
        if (isStrEmpty(_firstname) || isStrEmpty(_lastname)) {
            revert Vault__Missing_required_infos();
        }
        _;
    }

    // function userContactExists(string memory _firstname, string memory _lastname) public view returs (bool) {
    //     return contactFullnameToOwner[msg.se != msg.sender;
    // }

    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return
            bytes(a).length == bytes(b).length &&
            keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function computeFullname(
        string memory _firstname,
        string memory _lastname
    ) internal pure returns (string memory) {
        return string.concat(_firstname, "_", _lastname);
    }

    function isStrEmpty(string memory _str) internal pure returns (bool) {
        return bytes(_str).length == 0;
    }

    //// Modifiers

    modifier contactExists(uint256 _contactId) {
        if (!contactExisting[_contactId]) {
            revert Vault__Contact_not_exists(_contactId);
        }
        _;
    }

    modifier checkContactDuplicating(
        string memory _firstname,
        string memory _lastname
    ) {
        if (
            userContactFullnameExisting[msg.sender][
                computeFullname(_firstname, _lastname)
            ]
        ) {
            revert Vault__Contact_already_exists(_firstname, _lastname);
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != OWNER) {
            revert Vault__Not_the_owner();
        }
        _;
    }

    modifier onlyContactOwner(uint256 _contactId) {
        if (getContactOwner(_contactId) != msg.sender) {
            revert Vault__Not_the_contact_owner();
        }
        _;
    }

    // Getters

    function checkContactExisting(
        uint256 _contactId
    ) public view returns (bool) {
        return contactExisting[_contactId];
    }

    function getContactOwner(uint256 _contactId) public view returns (address) {
        return contactIdToOwner[_contactId];
    }

    function getContacts() public view returns (Contact[] memory) {
        return userContacts[msg.sender];
    }
}

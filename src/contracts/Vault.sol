// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Vault__Not_the_owner();
error Vault__Max_contacts_reached();
error Vault__Missing_required_infos();
error Vault__Contact_not_exists(uint256 _contactId);

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

    mapping(address user => uint256 lastContactIndex)
        public userLastContactIndex;
    mapping(address user => Contact[] contacts) public userContacts;
    mapping(address user => mapping(uint256 id => uint256 index))
        public userContactToIndex;
    mapping(address user => mapping(string category => uint256[] contactsIds))
        public userContactsByCategory;

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
        returns (Contact memory)
    {
        Contact[] storage contacts = userContacts[msg.sender];
        if (contacts.length == MAX_CONTACTS_PER_USER) {
            revert Vault__Max_contacts_reached();
        }

        if (bytes(_firstname).length == 0 || bytes(_lastname).length == 0) {
            revert Vault__Missing_required_infos();
        }

        uint256 newContactId = userLastContactIndex[msg.sender] + 1;
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
        userContactToIndex[msg.sender][newContactId] = contacts.length;

        emit ContactAdded(
            newContactId,
            _firstname,
            _lastname,
            _email,
            _phone,
            _category,
            _physicalAddress
        );

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
        requireLastNameAndFirstname(_firstname, _lastname)
    {
        Contact memory contact = Contact({
            id: _contactId,
            firstname: _firstname,
            lastname: _lastname,
            email: _email,
            phone: _phone,
            physicalAddress: _physicalAddress,
            category: _category
        });

        Contact[] storage contacts = userContacts[msg.sender];

        if (contacts.length < MAX_CONTACTS_PER_USER) {
            uint256 contactIndex = contacts.length;
            contacts[contactIndex] = contact;
        }

        emit ContactUpdated(
            _contactId,
            _firstname,
            _lastname,
            _email,
            _phone,
            _physicalAddress,
            _category
        );
    }

    function deleteContact(
        uint256 _contactId
    ) public contactExists(_contactId) {
        uint256 contactIndex = userContactToIndex[msg.sender][_contactId]; // Get contact index

        Contact[] storage contacts = userContacts[msg.sender]; // get user contacts
        uint256 contactsLength = contacts.length;

        uint256 latestContactId = contacts[contactsLength - 1].id; // Get the latest contact id to update his index in array later

        userContactToIndex[msg.sender][latestContactId] = contactIndex; // update index of the element moved

        contacts[contactIndex] = contacts[contacts.length - 1]; // replace value at the contactIndex by the latest value in the array
        contacts.pop(); // delete latest element

        emit ContactDeleted(_contactId);
    }

    function getContacts() public view returns (Contact[] memory) {
        Contact[] memory contacts = userContacts[msg.sender];

        return contacts;
    }

    function filterContactsByCategory(
        string memory _category
    ) public view returns (Contact[] memory) {
        uint256[] memory contactsIds = userContactsByCategory[msg.sender][
            _category
        ]; // Get contacts ids for the given category
        uint256 contactsIdLength = contactsIds.length;

        Contact[] memory _userContacts = userContacts[msg.sender];

        Contact[] memory resultContacts = new Contact[](0);

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
        if (bytes(_firstname).length == 0 || bytes(_lastname).length == 0) {
            revert Vault__Missing_required_infos();
        }
        _;
    }

    modifier contactExists(uint256 _contactId) {
        if (userContactToIndex[msg.sender][_contactId] == 0) {
            revert Vault__Contact_not_exists(_contactId);
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != OWNER) {
            revert Vault__Not_the_owner();
        }
        _;
    }

    // modifier checkContactUnicity(
    //     string memory _firstname,
    //     string memory _lastname
    // ) {
    //     _;
    // }

    // Getters
    // function getUserContacts(
    //     address _user
    // ) public view returns (Contact[MAX_CONTACTS_PER_USER]) {
    //     Contact[] memory contacts = userContacts[_user];
    // }
}

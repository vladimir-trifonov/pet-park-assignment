//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title PetPark
/// @notice PetPark is a contract that manages a simple pet park. It provides facilities
///         for adding animals to the park, for _users to borrow an animal, and for returning
///         the borrowed animal. The contract checks certain conditions based on age and gender
///         restrictions for each animal.
///         The contract uses access control, meaning certain functions can only 
///         be called by the owner of the contract (generally the deployer).
contract PetPark {
    /// @notice Represents the type of animal that can be borrowed from the park.
    enum AnimalType {
        None,
        Fish,
        Cat,
        Dog,
        Rabbit,
        Parrot
    }

    /// @notice Represents the gender of a user.
    enum Gender {
        Male,
        Female
    }

    /// @notice Represents a user of the park. It stores their age and gender.
    struct User {
        uint8 age;
        Gender gender;
    }

    event Added(AnimalType animal, uint256 count);
    event Borrowed(AnimalType animal);
    event Returned(AnimalType animal);

    address private _owner;
    mapping(AnimalType => uint256) public animalCounts;
    mapping(bytes32 => AnimalType) private _borrowers;
    mapping(bytes32 => User) private _users;

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    /// @notice Validation checks if the user can borrow an animal
    ///         based on age/gender.
    /// @dev Instead of using a multiple `if` statements, we use a bitmap to check the restrictions.
    ///      The hex"FF280A3A" represents the following restrictions:
    ///      - For male users if they are under 0xFF(Age: 255) they can borrow an animal,
    ///      which bit is set in the 0x0A(Binary: 0000 1010) bitmap i.e. Fish or Dog.
    ///      - For female users if they are under 0x28(Age: 40) they can borrow an animal,
    ///      which bit is set in the 0x3A(Binary: 0011 1010) bitmap i.e. all except the Cat.
    function _validateAgeGenderAnimal(
        uint8 _age,
        Gender _gender,
        AnimalType _animal
    ) private pure {
        string[2] memory errMessages = [
            "Invalid animal for men",
            "Invalid animal for women under 40"
        ];
        bytes memory _restrictions = hex"FF280A3A";
        bool _canBorrow;

        assembly {
            let _mask := 0xFE
            let _maxAge := shr(
                0xF8,
                mload(add(_restrictions, add(0x20, _gender)))
            )

            if lt(_age, _maxAge) {
                _mask := shr(
                    0xF8,
                    mload(add(_restrictions, add(0x22, _gender)))
                )
            }

            _canBorrow := and(_mask, shl(_animal, 1))
        }

        require(_canBorrow, errMessages[uint256(_gender)]);
    }

    /// @notice Allows the owner to add a specified count of a type of animal to the park.
    /// @param _animal  Animal type.
    /// @param _count   Animal count.
    function add(
        AnimalType _animal,
        uint256 _count
    ) external onlyOwner {
        require(_animal != AnimalType.None, "Invalid animal");

        uint256 count = animalCounts[_animal];

        assembly {
            count := add(count, _count)
        }

        animalCounts[_animal] = count;

        emit Added(_animal, _count);
    }

    /// @notice Allows a user to borrow a type of animal from the park,
    ///         after checking age and gender restrictions.
    /// @param _age     User's age.
    /// @param _gender  User's gender.
    /// @param _animal  Animal's type.
    function borrow(uint8 _age, Gender _gender, AnimalType _animal) external {
        require(_animal != AnimalType.None, "Invalid animal type");
        require(_age > 0, "Invalid Age");
        require(animalCounts[_animal] > 0, "Selected animal not available");

        bytes32 _borrower = keccak256(abi.encodePacked(msg.sender));

        require(
            _borrowers[_borrower] == AnimalType.None,
            "Already adopted a pet"
        );

        User storage _user = _users[_borrower];

        if (_user.age != 0) {
            require(_user.age == _age, "Invalid Age");
            require(_user.gender == _gender, "Invalid Gender");
        }

        _validateAgeGenderAnimal(_age, _gender, _animal);

        if (_user.age == 0) {
            _user.age = _age;
            _user.gender = _gender;
        }

        uint256 count = animalCounts[_animal];

        assembly {
            count := sub(count, 1)
        }

        animalCounts[_animal] = count;
        _borrowers[_borrower] = _animal;

        emit Borrowed(_animal);
    }

    /// @notice Allows a user to return a borrowed animal back to the park.
    function giveBackAnimal() external {
        bytes32 _borrower = keccak256(abi.encodePacked(msg.sender));
        AnimalType _animal = _borrowers[_borrower];

        require(_animal != AnimalType.None, "No borrowed pets");

        uint256 count = animalCounts[_animal];

        assembly {
            count := add(count, 1)
        }

        animalCounts[_animal] = count;
        delete _borrowers[_borrower];

        emit Returned(_animal);
    }
}

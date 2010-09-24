package HotelData;

use strict;
use warnings;

use Hotel;

###### Using columns for mapping that do not follow naming conventions
###### Using columns for mapping that are not primary key columns
###### Map tables using multiple columns

sub populate {
    my $class = shift;

    # Create data
    my $hotel = Hotel->create(
        name        => 'President',
        city        => 'New York',
        hotel_num_a => 5,
        apartments  => [
            {   apartment_num_b => 47,
                name            => 'John F. Kennedy',
                size            => 78,
                rooms           => [
                    {room_num_c => 1, size => 70},
                    {room_num_c => 2, size => 8}
                ]
            },
            {   apartment_num_b => 61,
                image_num_b     => 1000,
                name            => 'George Washington',
                size            => 50,
                rooms           => [
                    {room_num_c => 1, size => 10},
                    {room_num_c => 2, size => 16},
                    {room_num_c => 3, size => 70}
                ],
                images   => [
                    {   width   => 30,
                        height  => 120
                    }
                ]
            },
        ],
        manager => {
            manager_num_b   => 5555555,
            name            => 'Lalolu',
            telefon_numbers => [
                {tel_num_c => 1111, telefon_number => '123456789'},
                {tel_num_c => 1112, telefon_number => '987654321'}
            ],
            secretaries     => [
                {first_name => 'First1', last_name => 'Last1'},
                {first_name => 'First2', last_name => 'Last2'}
            ],
            office          => {size => 33, floor => 3},
            car             => {horsepower => 300, brand => 'Porsche'}
        }
    );

    # Create a second hotel to make tests a bit more demanding
    my $hotel2 = Hotel->create(
        name        => 'President2',
        city        => 'London',
        street      => 'Berlin Street',
        hotel_num_a => 6,
        apartments  => [
            {   apartment_num_b => 47,
                name            => 'John F. Kennedy',
                size            => 78,
                rooms           => [
                    {room_num_c => 1, size => 70},
                    {room_num_c => 2, size => 8}
                ]
            },
            {   apartment_num_b => 61,
                name            => 'George Washington',
                size            => 50,
                rooms           => [
                    {room_num_c => 1, size => 10, maid => {name => 'Amelie'}},
                    {room_num_c => 2, size => 15, maid => {name => 'Lucy'}},
                    {room_num_c => 3, size => 25, maid => {name => 'Sissy'}}
                ]
            },
        ],
        manager => {
            manager_num_b   => 666666,
            name            => 'Lalolu',
            telefon_numbers => [
                {tel_num_c => 1111, telefon_number => '123456789'},
                {tel_num_c => 1112, telefon_number => '987654329'}
            ]
        }
    );


    # Create a third hotel
    my $hotel3 = Hotel->create(
        name        => 'President3',
        city        => 'Paris',
        hotel_num_a => 7,
        apartments  => [
            {   apartment_num_b => 11,
                name            => 'John F. Kennedy',
                size            => 78,
                rooms           => [
                    {room_num_c => 1, size => 71},
                    {room_num_c => 2, size => 7}
                ]
            },
            {   apartment_num_b => 12,
                name            => 'George Washington',
                size            => 50,
                rooms           => [
                    {room_num_c => 1, size => 9},
                    {room_num_c => 2, size => 15},
                    {room_num_c => 3, size => 25},
                    {room_num_c => 4, size => 7},
                    {room_num_c => 5, size => 7}
                ]
            },
        ],
        manager => {
            manager_num_b   => 777777,
            name            => 'Smith',
            telefon_numbers => [
                {tel_num_c => 3111, telefon_number => '12121212'},
                {tel_num_c => 3222, telefon_number => '33445566'}
            ]
        }
    );

    return ($hotel, $hotel2, $hotel3);

}

sub cleanup {
    my $class = shift;

    Hotel->delete;
}

1;

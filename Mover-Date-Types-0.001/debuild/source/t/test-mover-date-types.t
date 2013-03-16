#!/usr/bin/perl
use Modern::Perl qw/2012/;
use DateTime;
use List::MoreUtils qw/any all/;
use Carp qw /confess/;
use POSIX;
use Test::More;

#use Test::Deep;
use Test::Exception;

#-------------------------------------------------------------------------------
#  Test Mover::Date Types
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Run environment check.
#-------------------------------------------------------------------------------
diag <<EOF
*******************************WARNING*****************************
The APP_TEST environment variable is not set. Please run this test
script with the APP_TEST variable set to one (e.g. APP_TEST=1 prove –l
to ensure that SmartComments and other stuff run in test only.
EOF
    if !$ENV{APP_TEST};

#------$env{app_test} is set in header script
plan skip_all => 'Set APP_TEST for the tests to run fully' if !$ENV{APP_TEST};

BEGIN {
    my $MyModule = 'Mover::Date::Types';
    use FindBin;

    #------Include header script
    require "$FindBin::Bin/my_test_template.pl";

    use_ok(
        $MyModule, qw/
            MoverDateTime
            MoverDateTimeRecent
            MoverDateStrYearFirst
            MoverDateStrMonthFirst
            MoverDateStrDayFirst
            MoverTimeStrHourFirst
            MoverDateTimeStrIso
            MoverDateUnit
            MoverDayInt
            MoverDayName
            MoverDayNameShort
            MoverMonthInt
            MoverMonthName
            MoverMonthNameShort
            MoverTimeHref
            MoverDateHref
            MoverDateTimeHref
            MoverUtcTz
            MoverBeforeOrAfter
            /
    ) || die "Bail out ! $!";

}

diag("Testing $MyModule  $Mover::Date::Types::VERSION, Perl $], $^X");

#-------------------------------------------------------------------------------
#  Constants
#-------------------------------------------------------------------------------

use Smart::Comments -ENV;

my $YES   = my $PASS = 1;
my $TRUE  = my $T    = 1;
my $NO    = 0;
my $FALSE = my $F    = 0;
my $UNDEF = undef;
my $FAIL  = $UNDEF;
my $EMPTY_STR     = q//;
my $ERROR_MESSAGE = q//;
my $EMPTY_BOX     = q/<empty>/;

#------ Mover Date Specific constants
my $DEFAULT_LANG = 'en';
my $UTC_TZ       = 'UTC';
my $NEW_YORK_TZ  = 'America/New_York';
my $LOCAL_TZ     = $NEW_YORK_TZ;

my $DATE_TIME_CLASS = 'DateTime';

#------- Constraints
#------- Constraintsp
my $DEFAULT_DELTA_TIME => 0;

my $MAX_DELTA_YEARS       = 10;
my $MAX_DELTA_MONTHS      = 120;
my $MAX_DELTA_WEEKS       = 520;
my $MAX_DELTA_DAYS        = 3600;
my $MAX_DELTA_HOURS       = 24;
my $MAX_DELTA_MINUTES     = 60;
my $MAX_DELTA_SECONDS     = 60;
my $MAX_DELTA_NANOSECONDS = 1000000000;

my %MonthToDays = (
    1  => 31,
    2  => 28,    # (Unless leap year => 29 ,)
    3  => 31,
    4  => 30,
    5  => 31,
    6  => 30,
    7  => 31,
    8  => 31,
    9  => 30,
    10 => 31,
    11 => 30,
    12 => 31,
);

#  switches between before and after. Pass current $before_or_after
#  $before_or_after = $toggle_before_or_after->(q/after/); # returns q/before/
my $toggle_before_or_after = sub { $_[0] =~ /^b/i ? q/after/ : q/before/; };

#-------------------------------------------------------------------------------
#  Subtype names
#-------------------------------------------------------------------------------
my ($test_mover_datetime, $test_date_extraction_types,
    $test_display_types,  $mover_date_time_wildcard_coersion
);

#-------------------------------------------------------------------------------
#  Test Switches
#-------------------------------------------------------------------------------

my $TEST_MOVER_DATETIME               = $T;
my $TEST_DATE_EXTRACTION_TYPES        = $T;
my $TEST_DISPLAY_TYPES                = $T;
my $MOVER_DATE_TIME_WILDCARD_COERSION = $T;

#-------------------------------------------------------------------------------
#  Testing the Class Instance
#-------------------------------------------------------------------------------
#--- Create the class
my $MoverDateTypes = $MyModule->new();

isa_ok( $MoverDateTypes, 'Mover::Date::Types',
    'Defined Mover-Date-Types instance' );

#-------------------------------------------------------------------------------
#  Test Data
#-------------------------------------------------------------------------------
# the "maybe_....." strings are to be used for coersion and extraction

my @not_recent_datetimes = (
    DateTime->new( year => 1929, month => 10, day => 1 ),
    DateTime->new( year => 4000, month => 7,  day => 31 )
);

my @ctl_day_names_long =
    (qw / monday tuesday wednesday thursday friday saturday sunday/);
my @ctl_day_names_short  = (qw/ mon tue wed thu fri sat sun/);
my @ctl_month_names_long = (
    qw / january february march april may june july august september october november december/
);
my @ctl_month_names_short =
    (qw / jan feb mar apr may jun jul aug sep oct nov dec/);

my @good_year_first_strings = (qw / 1944-6-4 2011\/12\/25 2013-7-22 /);

my @maybe_good_year_first_strings =
    ( " the date is 2003/12/11 \n", " in the year of 2005-12-21 " );

my @good_day_first_strings = (qw / 4-6-1944 25\/12\/2011 22-7-2013 /);

my @maybe_good_day_first_strings = (
    "the date is 01/07/1999 ",
    " lots of stuff 21-05-1945    and other stuff "
);

my @good_month_first_strings = (qw / 6-4-1944 12\/25\/2011 7-22-2011 /);

my @maybe_good_month_first_strings = (
    "the date is 07-30-2012   ,  and some other stuff in string....",
    " 12345667 10-22-1978 456789 "
);

my @good_hour_first_strings = (qw / 12:25:12 7:25 /);
my @maybe_good_hour_first_strings =
    ( "the time is 1:29 am ", " at approx 12.33 pm" );

my @good_iso_date_time_strings =
    (qw / 1999-12-31T11:59:59 2004\/07\/31_12.25.00 /);
my @maybe_good_iso_date_time_strings = (
    "the time is 1944-06-06 08:30:01  and counting",
    " 23:15:10 is the time"
);

my @maybe_good_past_date_times = (
    qw / 4-6-1944 25-12-2011 friday yesterday /,
    "last year",
    "last friday",
    "july 31,  1984",
    "three days ago",
    "last monday at noon",
    "Sep 4th,  2012"
);

my @maybe_good_future_date_times = (
    qw / 4-6-2013  tomorrow /,
    " next week ",
    "next tuesday,  2 pm",
    "tomorrow at 8pm ",
    "3 days, 2 hours",
    "August 2nd, 2013",
    " Now",

    #    " tomorrow evening",
);

#------ For testing Wildcard `
my $TestDateTime_1 = DateTime->new(
    year   => 2014,
    month  => 11,
    day    => 14,
    hour   => 06,
    minute => 15,
    second => '22'
);
my $TestDateTime_2 = DateTime->new(
    year   => 2001,
    month  => 06,
    day    => 27,
    hour   => 21,
    minute => 00,
    second => 00,
);

#-------------------------------------------------------------------------------
#  Test Data With Validation
#-------------------------------------------------------------------------------
# Keys are the dates to be tested, ArrayRef contains the expected
# results. Must pad out with 0's to get consistent results.
#
my %good_test_dates = (
    '2009-07-22 '         => [ 2009, 07, 22, 0,  0,  0 ],
    ' 1960/12/13  '       => [ 1960, 12, 13, 0,  0,  0 ],
    '2012-05-03T02:08:10' => [ 2012, 05, 03, 02, 8,  10 ],
    $TestDateTime_1       => [ 2014, 11, 14, 06, 15, 22 ],
    $TestDateTime_2       => [ 2001, 06, 27, 21, 0,  0 ],

    #--- Date::Manip will generate DateTime->now() when given
    #    a string with '1', Will truncate to 'Today' for test
    '1' => [
        DateTime->now( time_zone => $LOCAL_TZ )->year,
        DateTime->now( time_zone => $LOCAL_TZ )->month,
        DateTime->now( time_zone => $LOCAL_TZ )->day,
        0,
        0,
        0
    ],
    '22-07-1972' => [ 1972, 07, 22, 0, 0, 0 ],
);

my @good_hash_dates = (
    { year => 2007, month => 12, day => 25 },
    {   year   => 2010,
        month  => 1,
        day    => 1,
        hour   => 22,
        minute => 10,
        second => 15
    },
    {   year   => 1912,
        month  => 4,
        day    => 14,
        hour   => 9,
        minute => 5,
        second => 06
    },
    { year => 1944, month => 6,  day => 6, hour => 6, minute => 30, },
    { year => 19,   month => 11, day => 2, },
);

my %bad_test_dates = (
    '2013-02-29T22:21:20' => [ 2013, 02, 29, 22, 21, 20 ],
    '29-02-2013'          => [ 2013, 02, 29, 0,  0,  0 ],
    'Bad date'            => [ 0,    0,  0,  0,  0,  0 ],
);

#-------------------------------------------------------------------------------
#  Testing
#-------------------------------------------------------------------------------

ok( is_MoverDateTime( DateTime->now ), 'DateTime Now is a MoverDateTime' );

#-------------------------------------------------------------------------------
#  Test MoverDateTime types
#-------------------------------------------------------------------------------
subtest $test_mover_datetime => sub {
    plan skip_all => 'Not testing MoverDateTime dates now.'
        unless ($TEST_MOVER_DATETIME);
    use Smart::Comments -ENV;
    diag 'Test Good DateTime dates and date strings.';

    my $MoverDt1 = to_MoverDateTime($ControlDateTime)
        // diag
        'Failed to convert Control DateTime to MoverDateTime with coersion.';

    isa_ok( $MoverDt1, 'DateTime', 'MoverDateTime created a DateTime type.' );

    ok( is_MoverDateTime($ControlDateTime), 'MoverDateTime is a DateTime .' );
    ok( to_MoverDateTime($ControlDateTime),
        'MoverDateTime converts to DateTime .'
    );

    for my $OldieDt (@not_recent_datetimes) {
        isnt( $OldieDt->isa(MoverDateTimeRecent),
            1, 'Distant DateTimes are not recent.' );
        ok( is_MoverDateTimeRecent($ControlDateTime),
            'Recent DateTimes are recent.' );
    }

};    # End testing of MoverDateTime types

#-------------------------------------------------------------------------------
#  Test Date Exraction Types
#-------------------------------------------------------------------------------
subtest $test_date_extraction_types => sub {

    plan skip_all => 'Not testing date string extraction.'
        unless ($TEST_DATE_EXTRACTION_TYPES);

    my @good_year_first_strings = (qw / 1944-6-4 2011\/12\/25 2013-7-22 /);

    diag 'Testing Date String Extraction Types ';

    diag 'Testing Year first strings.';
    for my $test_string (@good_year_first_strings) {
        is( is_MoverDateStrYearFirst($test_string), $TRUE,
            $test_string
                . ' conains a valid yyyymmdd formatted date string.' );
        isnt( is_MoverDateStrMonthFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid mmddyyyy formatted date string.' );
        isnt( is_MoverDateStrDayFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid euro style ddmmyyyy formatted date string.'
        );
        isnt( is_MoverTimeStrHourFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid hhmmssampm formatted date time.' );
    }
    diag 'Testing Coerced Year first strings.';
    for my $test_string (@maybe_good_year_first_strings) {
        my $date_only_str = to_MoverDateStrYearFirst($test_string);
        is( is_MoverDateStrYearFirst($date_only_str), $TRUE,
            ( $date_only_str // $EMPTY_BOX )
                . ' was extracted and is a good yyyymmdd string.' );
    }

    diag 'Testing Month first strings.';
    for my $test_string (@good_month_first_strings) {
        is( is_MoverDateStrMonthFirst($test_string), $TRUE,
            $test_string
                . ' conains a valid mmddyyyy formatted date string.' );
        isnt( is_MoverDateStrYearFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid yyyymmdd formatted date string.' );
    }

    diag 'Testing Coerced Month first strings.';
    for my $test_string (@maybe_good_month_first_strings) {
        my $date_only_str = to_MoverDateStrMonthFirst($test_string);
        is( is_MoverDateStrMonthFirst($date_only_str), $TRUE,
            ( $date_only_str // $EMPTY_BOX )
                . ' was extracted and is a good mmddyyyy string.' );
    }

    diag 'Testing Day first strings.';
    for my $test_string (@good_day_first_strings) {
        is( is_MoverDateStrDayFirst($test_string), $TRUE,
            $test_string
                . ' contains a valid euro style ddmmyyyy formatted date string.'
        );
        isnt( is_MoverDateStrYearFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid yyyymmdd formatted date string.' );
        isnt( is_MoverDateTimeStrIso($test_string),
            $TRUE, $test_string . ' dosent contain a valid Iso string.' );
    }

    diag 'Testing Coerced Day first (Euro) strings.';
    for my $test_string (@maybe_good_day_first_strings) {
        my $date_only_str = to_MoverDateStrDayFirst($test_string);
        is( is_MoverDateStrDayFirst($date_only_str), $TRUE,
            ( $date_only_str // $EMPTY_BOX )
                . ' was extracted and is a good ddmmyyyy euro style string.'
        );
    }

    diag 'Testing Hour first strings.';
    for my $test_string (@good_hour_first_strings) {
        is( is_MoverTimeStrHourFirst($test_string),
            $TRUE, $test_string . ' contains a valid hhmmssampm string.' );
        isnt( is_MoverDateStrMonthFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid mmddyyyy formatted date string.' );
        isnt( is_MoverDateStrYearFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid yyyymmdd formatted date string.' );
    }
    diag 'Testing Coerced Hour first time strings.';
    for my $test_string (@maybe_good_hour_first_strings) {
        my $date_only_str = to_MoverTimeStrHourFirst($test_string);
        is( is_MoverTimeStrHourFirst($date_only_str), $TRUE,
            ( $date_only_str // $EMPTY_BOX )
                . ' was extracted and is a good hhmmssampm string.' );
    }

    diag 'Testing Iso Date time extraction strings.';
    for my $test_string (@good_iso_date_time_strings) {
        is( is_MoverDateTimeStrIso($test_string),
            $TRUE, $test_string . ' contains a valid Iso string.' );
        isnt( is_MoverDateStrMonthFirst($test_string), $TRUE,
            $test_string
                . ' dosent contain a valid Iso formatted date string.' );
    }

    diag 'Testing Coerced Iso Date Time Strings.';
    for my $test_string (@maybe_good_iso_date_time_strings) {
        my $date_only_str = to_MoverDateTimeStrIso($test_string);
        is( is_MoverDateTimeStrIso($date_only_str), $TRUE,
            ( $date_only_str // $EMPTY_BOX )
                . ' was extracted and is a good Date Time ISO string.' );
    }

};    #------ End test_date_extraction types

#-------------------------------------------------------------------------------
#  Test Convenient Date Display types
#-------------------------------------------------------------------------------
subtest $test_display_types => sub {

    plan skip_all => 'Not testing display types.'
        unless ($TEST_DISPLAY_TYPES);

#-------------------------------------------------------------------------------
#   Days and Weeks
#-------------------------------------------------------------------------------
    diag 'Testing MoverDayInt ';
    for my $test_int (qw/1 4 7/) {
        is( is_MoverDayInt($test_int),
            $TRUE, $test_int . ' is a valid Week day number.' );
    }
    for my $test_int (qw/0 8/) {
        isnt( is_MoverDayInt($test_int),
            $TRUE, $test_int . ' is not a valid Week day number.' );
    }
    diag 'Testing MoverDayName';
    for my $test_day (
        qw / monday tuesday wednesday thursday friday saturday sunday/)
    {
        is( is_MoverDayName($test_day),
            $TRUE, $test_day . ' is a valid  day name.' );
    }
    for my $test_day (qw / mon tue december august/) {
        isnt( is_MoverDayName($test_day),
            $TRUE, $test_day . ' is not a valid day name.' );
    }

    diag 'Testing coercions to MoverDayName';

    my $found_day_name;
    ok( $found_day_name =
            to_MoverDayName( DateTime->now( time_zone => $LOCAL_TZ ) ),
        ' to_MoverDayName worked ok.'
    );

    #----- Test coercion of DateTime object,  integer and day abbreviations to
    #      to day name long
    is_any( $found_day_name, \@ctl_day_names_long,
        ' DateTime Object is coerced to a valid long day name.' );
    for my $test_day_number (qw/1 5 7/) {
        is_any( to_MoverDayName($test_day_number),
            \@ctl_day_names_long,
            ' Day Number is coerced to a valid long day name.' );
    }
    for my $test_day_abbr (qw/mon f thu sat su/) {
        is_any( to_MoverDayName($test_day_abbr),
            \@ctl_day_names_long,
            ' Day abbr is coerced to a valid long day name.' );
    }

    diag 'Testing coercions to MoverDayNameShort';

    ok( $found_day_name =
            to_MoverDayNameShort( DateTime->now( time_zone => $LOCAL_TZ ) ),
        'to_MoverDayNameShort short from DateTime worked ok!'
    );

    #----- Test coercion of DateTime object,  integer and day abbreviations to
    #      to day name short
    is_any( $found_day_name, \@ctl_day_names_short,
        ' DateTime Object is coerced to a valid short day name.' );
    for my $test_day_number (qw/1 5 7/) {
        is_any( to_MoverDayNameShort($test_day_number),
            \@ctl_day_names_short,
            ' Day Number is coerced to a valid short day name.' );
    }
    for my $test_day_abbr (qw/mon f thu sat su/) {
        is_any( to_MoverDayNameShort($test_day_abbr),
            \@ctl_day_names_short,
            ' Day abbr is coerced to a valid short day name.' );
    }

#-------------------------------------------------------------------------------
#   Months
#-------------------------------------------------------------------------------
    diag 'Testing MoverMonthInt ';
    for my $test_int (qw/1 4 12/) {
        is( is_MoverMonthInt($test_int),
            $TRUE, $test_int . ' is a valid Month number.' );
    }
    for my $test_int (qw/0 13/) {
        isnt( is_MoverMonthInt($test_int),
            $TRUE, $test_int . ' is not a valid Month number.' );
    }

    diag 'Testing MoverMonthName';
    for my $test_month (qw / january december july/) {
        is( is_MoverMonthName($test_month),
            $TRUE, $test_month . ' is a valid long month name.' );
    }
    for my $test_month (qw / dec nov arm/) {
        isnt( is_MoverMonthName($test_month),
            $TRUE, $test_month . ' is not a valid long month name.' );
        ok( to_MoverMonthName( DateTime->now( time_zone => $LOCAL_TZ ) ),
            ' to_MoverMonthName from DateTime Object worked.'
        );

    }
    diag 'Testing Coercions to MoverMonthName';

    my $TempDt = DateTime->now( time_zone => $LOCAL_TZ );
    ok( is_MoverDateTime($TempDt), 'DateTime is also a MoverDateTime.' );

    my $found_month_name;
    ok( to_MoverMonthName( DateTime->now( time_zone => $LOCAL_TZ ) ),
        ' to_MoverMonthName from DateTime Object worked.'
    );

    ok( to_MoverMonthName($TempDt),
        ' to_MoverMonthName DateTime Object worked.try again with one I prepared earlier. '
    );

    $found_month_name =
        to_MoverMonthName( DateTime->now( time_zone => $LOCAL_TZ ) ),
        ### Whats in to_MoverMonthName : $found_month_name
  #----- Test coercion of DateTime object,  integer and month abbreviations to
  #      to month name long
        is_any( $found_month_name, \@ctl_month_names_long,
        ' DateTime Object is coerced to a valid long month name.' );
    for my $test_month_number (qw/1 6 12/) {
        ### Testing Number : $test_month_number
        is_any( to_MoverMonthName($test_month_number),
            \@ctl_month_names_long,
            ' Month Number is coerced to a valid long month name.' );
    }

    for my $test_month_abbr (qw/feb mar D /) {
        is_any(
            to_MoverMonthName($test_month_abbr) // $EMPTY_BOX,
            \@ctl_month_names_long,
            ' Month abbr is coerced to a valid long month name.'
        );
    }

    #--------
    #  Short Month Names
    #-------

    diag 'Testing MoverMonthNameShort';
    for my $test_month (qw / jan dec jul/) {
        is( is_MoverMonthNameShort($test_month),
            $TRUE, $test_month . ' is a valid short month name.' );
    }
    for my $test_month (qw / december august 13 /) {
        isnt( is_MoverMonthNameShort($test_month) // $EMPTY_BOX,
            $TRUE, $test_month . ' is not a valid short month name.' );
    }

    diag 'Testing Coercions to MoverMonthNameShort';

    ok( $found_month_name =
            to_MoverMonthNameShort( DateTime->now( time_zone => $LOCAL_TZ ) ),
        ' to_MoverMonthNameShort from DateTime Object works.'
    );

    ### Found Short Month Name : $found_month_name
  #----- Test coercion of DateTime object,  integer and month abbreviations to
  #      to month name short
    is_any( $found_month_name, \@ctl_month_names_short,
        ' DateTime Object is coerced to a valid short month name.' );
    for my $test_month_number ( 1, 6, 12 ) {
        is_any(
            to_MoverMonthNameShort($test_month_number) // $EMPTY_BOX,
            \@ctl_month_names_short,
            ' Month Number is coerced to a valid short month name.'
        );
    }

    #------ Coerce variouis  Month abbreviations to Month Short name
    is( to_MoverMonthNameShort("march"), "mar", 'Mar works' );
    for my $test_month_abbr (qw/ja f mar De/) {
        is_any(
            to_MoverMonthNameShort($test_month_abbr) // $EMPTY_BOX,
            \@ctl_month_names_short,
            ' Month abbr is coerced to a valid short month name.'
        );
    }

};    #------ End testing Date display types.

#-------------------------------------------------------------------------------
# Test converting strings,  DateTimes and Hashes to MoverDateTime
# through coersion to_MoverDateTime
#-------------------------------------------------------------------------------
subtest $mover_date_time_wildcard_coersion => sub {
    plan skip_all => 'Not testing MoverDateTime this time.'
        unless ($MOVER_DATE_TIME_WILDCARD_COERSION);
    diag 'Test coersion to MoverDateTime from various other types.';

    for my $good_date_type ( keys %good_test_dates ) {
        my $GotDt = undef;
        isa_ok( $GotDt = to_MoverDateTime($good_date_type),
            'DateTime',
            'Coerced to MoverDateTime from ' . dump($good_date_type) );
        if ( $good_date_type == 1 ) {
            $GotDt = $GotDt->truncate( to => 'day' );
        }
        is_datetime_eq_array( $GotDt, $good_test_dates{$good_date_type},
            'Coerced DateTime from various input contains correct date values.'
        );
    }

    for my $date_href (@good_hash_dates) {
        my $GotDt = undef;
        isa_ok( $GotDt = to_MoverDateTime($date_href),
            'DateTime', 'Coerced to MoverDateTime from ' . dump($date_href) );
        is_datetime_eq_hashref( $GotDt, $date_href,
            'Coerced DateTime from HashRef contains correct date values.' );
    }
    diag 'Testing some bad dates.Some with Feb 29 with no leap year etc.';
    for my $bad_date_type ( keys %bad_test_dates ) {
        is( to_MoverDateTime($bad_date_type), $FAIL,
            'Cannot coerce bad date to MoverDateTime from '
                . dump($bad_date_type) );
    }

    diag 'Testing some very iffy dates.';
    for my $iffy_date ( @maybe_good_past_date_times,
        @maybe_good_future_date_times )
    {
        my $IffyDt;
        isa_ok(
            $IffyDt = to_MoverDateTime($iffy_date),
            'DateTime',
            "Iffy date coerced to MoverDateTime from:\n "
                . dump($iffy_date)
                . "\nTo :\n"
                . (
                $IffyDt
                ? dump( $IffyDt->ymd . $IffyDt->hms )
                : q/Got no DateTime! /
                )
        );
    }

};    # End date time wildcard conv

#-------------------------------------------------------------------------------
#  Useful Subs
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#  Pass actual result,  ArayRef of expected results and test name.
#-------------------------------------------------------------------------------
sub is_any {
    confess("Must send three Paramaters to is_any test.") unless ( @_ == 3 );
    my ( $got, $expected, $info_msg ) = @_;

    $info_msg //= '';
    $got      //= 'Got Nothing';
    ok( ( any { $_ eq $got } @$expected ), $info_msg )
        or diag "Failed the is_any test.\nReceived: " 
        . $got
        . "\nExpected:\n"
        . join "",
        map {"         $_\n"} @$expected;

}

#------
sub is_all {

    confess("Must send three Paramaters to is_all test.") unless ( @_ == 3 );
    my ( $actual, $expected, $name ) = @_;

    $name //= '';

    ok( ( all { $_ eq $actual } @$expected ), $name )

        or diag "Received: $actual\nExpected:\n" .

        join "", map {"         $_\n"} @$expected;

}

#-------------------------------------------------------------------------------
#  Compare a Got: DateTime with an Expected: HashRef
#-------------------------------------------------------------------------------
sub is_datetime_eq_hashref {
    my ( $GotDt, $expected_href, $info_msg ) = @_;
    confess('Must send an expected HashRef!')
        unless ( ref($expected_href) eq 'HASH' );
    ### Using is_datetime_eq_hashref with
    ### Got DateTime : $GotDt->ymd()
    $info_msg //= 'DateTime data corresponds to HashRef data.';
    $GotDt //= fail($info_msg);
    if ( !$GotDt ) {
        fail($info_msg);
        diag 'Received: '
            . ( $GotDt // q/No DateTime Object/ )
            . "\nExpected:\n"
            . join "", map {"         $_\n"} keys %$expected_href;
        return $FAIL;
    }
    my $got_href;

    #--- Populate Got Hash with data from GotDt
    $got_href->{year}   = $GotDt->year()   if $GotDt->year();
    $got_href->{month}  = $GotDt->month()  if $GotDt->month();
    $got_href->{day}    = $GotDt->day()    if $GotDt->day();
    $got_href->{hour}   = $GotDt->hour()   if $GotDt->hour();
    $got_href->{minute} = $GotDt->minute() if $GotDt->minute();
    $got_href->{second} = $GotDt->second() if $GotDt->second();
    is_deeply( $got_href, $expected_href, $info_msg );
}

#-------------------------------------------------------------------------------
#  Compare a Got: DateTime with an Expected: ArrayRef
#  Array must be populated in the correct order.
#  year, month, day, hour, minute, second (or 0 in missing field)
#-------------------------------------------------------------------------------
sub is_datetime_eq_array {
    my ( $GotDt, $expected_array_ref, $info_msg ) = @_;
    confess('Must send an expected ArrayRef!')
        unless ( ref($expected_array_ref) eq 'ARRAY' );
    ### Using is_datetime_eq_array with
    ### Got DateTime : $GotDt->ymd()
    $info_msg //= 'DateTime data corresponds to Array data.';
    if ( !$GotDt ) {
        fail($info_msg);
        diag 'Received: '
            . ( $GotDt // q/No DateTime Object/ )
            . "\nExpected:\n"
            . join "", map {"         $_\n"} @$expected_array_ref;
        return $FAIL;
    }
    my $got_array_ref;

    #--- Populate Got Array with data from GotDt
    $got_array_ref = [
        $GotDt->year()   // 0,
        $GotDt->month()  // 0,
        $GotDt->day()    // 0,
        $GotDt->hour()   // 0,
        $GotDt->minute() // 0,
        $GotDt->second() // 0,
    ];
    is_deeply( $got_array_ref, $expected_array_ref, $info_msg );

}

#-------------------------------------------------------------------------------
#  Temporary end marker
#-------------------------------------------------------------------------------
done_testing();
__END__

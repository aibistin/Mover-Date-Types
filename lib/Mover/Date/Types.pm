#===============================================================================
#         FILE: Mover/Date/Types.pm
#
#  DESCRIPTION: Mover Moose Types for Dates and Times
#
#  AUTHOR: Austin Kenny (), aibistin.cionnaith@gmail.com
#  CREATED: 02/20/2013 11:20:37 PM
#
#===============================================================================
use Modern::Perl q/2012/;
use autodie;

package Mover::Date::Types;

our $VERSION = q/0.002/;    # from D Golden blog
$VERSION = eval $VERSION;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

#-------------------------------------------------------------------------------
#  Note to self: Dont put any Roles here that will use Mover::Date::Types
#-------------------------------------------------------------------------------
use String::Util qw/trim crunch hascontent/;
use Scalar::Util qw/blessed/;
use Regexp::Common qw/time/;
use Smart::Comments -ENV;
use Log::Any qw/$log/;
use DateTime;
use Try::Tiny;
use MooseX::Types::Moose qw( HashRef Object Value);

use MooseX::Types::Common::Numeric qw( PositiveInt SingleDigit);
use MooseX::Types::Common::String qw( NonEmptyStr NonEmptySimpleStr);

use MooseX::Types -declare => [
    qw/
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
];

#-------------------------------------------------------------------------------
#  Constants
#-------------------------------------------------------------------------------
use Readonly;

Readonly my $FAIL      => undef;
Readonly my $EMPTY_STR => q//;
Readonly my $EMPTY     => q/<empty>/;

#------ Mover Date Specific constants
Readonly my $F_SLASH => '/';
Readonly my $B_SLASH => '\\';
Readonly my $DASH    => '-';
Readonly my $DOT     => '.';

#--- To be moved to config file later.....
Readonly my $MIN_MOVER_YEAR => 1950;
Readonly my $MAX_MOVER_YEAR => 2100;

#------ Lists
my $DATE_UNIT_REGEX = qr/(?<date_unit>year|month|week|day|hour|minute)s?/;

my $BEFORE_OR_AFTER_REGEX = qr/(?<before_or_after>before|after)/;

my $DELTA_DATE_UNIT_REGEX = qr/(?<delta_date_units>\d{1,6})/;

#-------------------------------------------------------------------------------
#  Date Time Regex Formats
#-------------------------------------------------------------------------------

my $year_rx        = qr/(?<year>[0-9][0-9][0-9][0-9])/;
my $month_rx       = qr/(?<month>[0-1]?[0-9])/;
my $day_rx         = qr/(?<day>[0-3]?[0-9])/;
my $date_seperator = qr/[\-\/\.]/;

# yyyy-mm-dd,  yyyy/mm/dd yyyy.mm.dd yyy/m/d
Readonly my $YYYY_MM_DD_REGEX =>
    qr/$year_rx$date_seperator$month_rx$date_seperator$day_rx/;

# mm-dd-yyyy,  mm/dd/yyyy mm.dd.yyyy m-d-yyyy
Readonly my $MM_DD_YYYY_REGEX =>
    qr/$month_rx$date_seperator$day_rx$date_seperator$year_rx/;

# dd-mm-yyyy,  dd/mm/yyyy dd.mm.yyyy d/m/yyyy
Readonly my $DD_MM_YYYY_REGEX =>
    qr/$day_rx$date_seperator$month_rx$date_seperator$year_rx/;

#----- Time Regex's
my $hour_rx             = qr/(?<hour>[0-2][0-9])/;
my $minute_rx           = qr/(?<minute>[0-6][0-9])/;
my $second_rx           = qr/(?<second>[0-6][0-9])/;
my $maybe_am_or_pm_rx   = qr/(?<am_or_pm>[aApP][mM])?/;
my $time_seperator      = qr/[:\.]/;
my $maybe_space_rx      = qr/\s?/;
my $maybe_space_or_t_rx = qr/[\s|t|T]?/;

#------ A little similar
#--- mm-dd-yyyy HH:MM:SS AM mm/dd/yyyy HH:MM:SSAM mm/dd/yyyy HH:MM:SS
Readonly my $MM_DD_YYYY_HH_MM_SS_AMPM =>
    qr/$month_rx$date_seperator$day_rx$date_seperator$year_rx$maybe_space_or_t_rx
$hour_rx$time_seperator$minute_rx$time_seperator$second_rx$maybe_space_rx$maybe_am_or_pm_rx/;

#--- HH:MM:SS,  HH:MM:SS AM,  HH:MM:SSPM
Readonly my $HH_MM_SS_AMPM =>
    qr/$hour_rx$time_seperator$minute_rx$time_seperator$second_rx$maybe_space_rx$maybe_am_or_pm_rx/;

#-------------------------------------------------------------------------------
#  DateTime Types
#-------------------------------------------------------------------------------
class_type 'DateTime';

=head2 MoverDateTime
 A 'DateTime' object for the Mover project.
     
=cut

subtype MoverDateTime, as Object, where {
    $_->isa('DateTime');
}, message {
    ( ( try {$_} ) // '<No DateTime>' ) . ' is not a DateTime Object!';
};

=head2 MoverDateTimeRecent
 A 'DateTime' object that is not too far into the past or the future.

=cut

subtype MoverDateTimeRecent, as MoverDateTime, where {
    ( $_->year() > $MIN_MOVER_YEAR ) && ( $_->year() < $MAX_MOVER_YEAR );

}, message {
    ( ( try { $_->year() } ) // '<No DateTime>' )
        . ' is outside our date range!';
};

#-------------------------------------------------------------------------------
#  Time zone params
#-------------------------------------------------------------------------------

=head2 MoverUtcTz
 UTC time zone.
 Can be coerced from any string that contains 'UTC' 

=cut

subtype MoverUtcTz, as NonEmptyStr, where {
    $_ eq 'UTC';
}, message {'Not a valid UTC time string.'};

coerce MoverUtcTz, from NonEmptyStr, via { uc $_; };

=head2 MoverDateUnit
 String to represent date units,  year, month, week, day, hour, minute.
 Can be coerced from any string that contains the first one of these to 
 be found using regex.

=cut

subtype MoverDateUnit, as NonEmptyStr, where { $_ =~ /^$DATE_UNIT_REGEX$/ };

coerce MoverDateUnit, from NonEmptyStr, via {
    if ( $_ =~ /DATE_UNIT_REGEX/i ) {
        return lc( $+{date_unit} );
    }
};

=head2 MoverBeforeOrAfter
 String to represent before_or_after, a particular date.
 q/before/ or q/after/
 Can be coerced from any string that contains before or after.

=cut

subtype MoverBeforeOrAfter, as NonEmptyStr, where {
    $_ =~ /^$BEFORE_OR_AFTER_REGEX$/;
};

coerce MoverBeforeOrAfter, from NonEmptyStr, via {
    if ( $_ =~ /BEFORE_OR_AFTER_REGEX/i ) {
        return lc( $+{before_or_after} );
    }
};

#-------------------------------------------------------------------------------
#  Date And Time String Validation Types
#-------------------------------------------------------------------------------
#--- Validate Year-First date

=head2 MoverDateStrYearFirst
 A string to represent a date with the year first
 YYYY/MM/DD corresponding to Regex Commom 
 $RE{time}{ymd}

=cut

subtype MoverDateStrYearFirst, as NonEmptyStr,
    where { $_ =~ /^$YYYY_MM_DD_REGEX$/ },
    message {"Invalid format for Year First Date string: $_"};

=head2 MoverDateTimeStrIso (ISO-8601)
 A string to represent a date in ISO-8601 format
 Corresponding to Regex Commom 
 $RE{time}{iso}{-keep}
 $1 = full match, $2 = year, $3 = month, 
 $4 = day .. $7 = second.

=cut

subtype MoverDateTimeStrIso, as NonEmptyStr,
    where {/^$RE{time}{iso}{-keep}$/},
    message {"Invalid format for Iso-8601 Date string: $_"};

=head2 MoverDateStrMonthFirst
 A string to represent a date with the month first
 MM/DD/YYYY corresponding to Regex Commom 
 $RE{time}{mdy}

=cut

subtype MoverDateStrMonthFirst,
    as NonEmptyStr,
    where { $_ =~ /^$MM_DD_YYYY_REGEX$/; },
    message {"Invalid format for Month First Date string: $_"};

#--- Validate European style date

=head2 MoverDateStrDayFirst
 A string to represent a date with the day first
 (European style.)
 DD/MM/YYYY corresponding to Regex Commom 
 $RE{time}{dmy}

=cut

subtype MoverDateStrDayFirst, as NonEmptyStr,
    where { $_ =~ /^$DD_MM_YYYY_REGEX$/ },
    message {"Invalid format for Day First Date string: $_"};

#-------------------------------------------------------------------------------
#  DateTime Hashref Types
#-------------------------------------------------------------------------------

#------ DateTime expressed as Hashref

=head2 MoverDateTimeHref
 DateTime represented by as HashRef.
 {
   year    => $year, 
   month   => $month, 
   day     => $day, 
   hour    => $hour, 
   minute  => $minute, 
   second  => $second, 
#--- with optional 
   am_or_pm => q//, 
   time_zone => q//, 
  }
 
=cut

subtype MoverDateTimeHref, as HashRef, where {
           defined $_->{year}
        && defined $_->{month}
        && defined $_->{day}
        && defined $_->{hour}
        && defined $_->{minute}
        && ( exists $_->{second} );
}, message {"Invalid format for Date Time Hashref $_"};

=head2 MoverDateHref
 Date represented by a HashRef.
 {
   year  => $year, 
   month => $month, 
   day   => $day, 
   # with optional
   time_zone => $_->time_zone, 
 }
 
=cut

subtype MoverDateHref, as HashRef, where {
           defined $_->{year}
        && defined $_->{month}
        && defined $_->{day}
        && ( not exists $_->{hour} )
        && ( not exists $_->{minute} )
        && ( not exists $_->{second} );
}, message {"Invalid format for Date Hashref $_"};

#---- Time experssed as a HashRef

=head2 MoverTimeHref
 Time represented by a HashRef.
 {
   hour         => $hour, 
   minute       => $minute, 
   # with optional
   second       => $second, 
   nanosecond   => $nanosecond, 
   am_or_pm     => q//, 
   time_zone    => q//, 
 }
 
=cut

subtype MoverTimeHref, as HashRef, where {
    defined $_->{hour} && defined $_->{minute} && exists $_->{second};
}, message {"Invalid format for Date Hashref $_"};

#-------------------------------------------------------------------------------
#  DateTime String Coersions
#-------------------------------------------------------------------------------

coerce MoverDateStrYearFirst,

    #--- Get ymd string from DateTime Object
    from 'DateTime', via { $_->ymd() },

    #--- Get ymd string from String
    from NonEmptyStr, via {
    ### Types checking year first date : $_
    if ( $_ =~ $YYYY_MM_DD_REGEX ) {
        return $+{year} . $F_SLASH . $+{month} . $F_SLASH . $+{day};
    }
    }, from MoverDateTimeHref, via {
    sprintf( "%04u/%02u/%02", $_->{year}, $_->{month}, $_->{day} );
    };

#--- Validate USA style date
coerce MoverDateStrMonthFirst,

    #--- Get mdy string from DateTime Object
    from 'DateTime', via { $_->mdy() },

    #--- Get mdy string from string
    from NonEmptyStr, via {
    if ( $_ =~ $MM_DD_YYYY_REGEX ) {
        ### MMDDYYYY Coersion matched : $+{month}.' '.$+{day}.' '.$+{year}
        return $+{month} . $F_SLASH . $+{day} . $F_SLASH . $+{year};
    }
    }, from MoverDateTimeHref, via {
    sprintf( "%02u/%02u/%04", $_->{month}, $_->{day}, $_->{year} );
    };

=head2 coerce MoverDateStrYearFirst MoverDateStrMonthFirst MoverDateStrDayFirst
      from any string containing a date in one of these formats.

=cut

coerce MoverDateStrDayFirst,

    #--- Get euro style dmy string from Datetime
    from 'DateTime', via { $_->dmy() },

    #--- Get euro style dmy string from string
    from NonEmptyStr, via {
    if ( $_ =~ $DD_MM_YYYY_REGEX ) {
        return $+{day} . $F_SLASH . $+{month} . $F_SLASH . $+{year};
    }
    }, from MoverDateTimeHref, via {
    sprintf( "%02u/%02u/%04", $_->{day}, $_->{month}, $_->{year} );
    };

=head2 coerce MoverDateTimeStrIso 
 from any string containing a date in ISO-8601 format
 using $RE{time}{iso}{-keep}.
 from DateTime object, using the default DateTime stringification
 method.
=cut

coerce MoverDateTimeStrIso, from NonEmptyStr, via {
    if ( $_ =~ $RE{time}{iso}{-keep} ) { return $1; }
}, from MoverDateTimeHref, via {
    sprintf(
        "%04u-%02u-%02uT%02u:%02u:%02u",
        $_->{year}, $_->{month},  $_->{day},
        $_->{hour}, $_->{minute}, $_->{second},
    );

}, from MoverDateTime, via { $_ . $EMPTY_STR; };

#---------------Times

=head2 MoverTimeStrHourFirst
 A string to represent a time in HH:MM:SS format
 Corresponding to Regex Common 
 $RE{time}{hms}

=cut

subtype MoverTimeStrHourFirst, as NonEmptyStr,
    where {/^$RE{time}{hms}$/},
    message {"Invalid format for Hour First Time string: $_"};

=head2 coerce MoverTimeStrHourFirst
 from 'DateTime' Object, 
 or from a string containing hms using $RE{time}{hms}{-keep}

=cut

coerce MoverTimeStrHourFirst, from 'DateTime', via { $_->hms() },

    #--- Extract hhmmss from string
    from NonEmptyStr, via {
    if ( $_ =~ $RE{time}{hms}{-keep} ) { return $1; }
    };

#-------------------------------------------------------------------------------
#      DateTime HashRef Coersions
#-------------------------------------------------------------------------------

=head2 coerce MoverDateTimeHref
 From an ISO 8601 string
 from MoverDateHref
 and from a DateTime Object

=cut

coerce MoverDateTimeHref, from MoverDateTimeStrIso, via {

    #--- More detailed ISO datetime string extraction using Regexp Common
    #    Time ISO-8601
    if ( $_ =~ $RE{time}{iso}{-keep} ) {
        return {
            year   => $2 + 0,
            month  => $3 + 0,
            day    => $4 + 0,
            hour   => ( $5 // 0 ) + 0,
            minute => ( $6 // 0 ) + 0,
            second => ( $7 // 0 ) + 0,
        };
    }
}, from MoverDateHref, via {
    return {
        year      => $_->{year} + 0,
        month     => $_->{month} + 0,
        day       => $_->{day} + 0,
        time_zone => $_->{time_zone} // undef,
    };

}, from MoverDateTime, via {
    ### Coerce MoverDateTimeHref from MoverDateTime.....
    ### the MoverDateTime is : $_ . ""
    return {
        year      => $_->year + 0,
        month     => $_->month + 0,
        day       => $_->day + 0,
        hour      => ( $_->hour // 0 ) + 0,
        minute    => ( $_->minute // 0 ) + 0,
        second    => ( $_->second // 0 ) + 0,
        am_or_pm  => $_->am_or_pm,
        time_zone => $_->time_zone,
    };
};

#------ Date expressed as Hashref

=head2 coerce MoverDateHref
 From a string in MoverDateStrYearFirst format
 from a string in MoverDateStrMonthformat
 from a string in MoverDateStrDayFirst format
 from a string in MoverDateTimeStrIso format
 from DateTime format

=cut

coerce MoverDateHref, from MoverDateStrYearFirst, via {
    if ( $_ =~ $YYYY_MM_DD_REGEX ) {
        return {
            year  => $+{year} + 0,
            month => $+{month} + 0,
            day   => $+{day} + 0,
        };
    }
}, from MoverDateStrMonthFirst, via {
    if ( $_ =~ $MM_DD_YYYY_REGEX ) {
        return {
            year  => $+{year} + 0,
            month => $+{month} + 0,
            day   => $+{day} + 0,
        };
    }
}, from MoverDateStrDayFirst, via {

    if ( $_ =~ $DD_MM_YYYY_REGEX ) {
        return {
            year  => $+{year} + 0,
            month => $+{month} + 0,
            day   => $+{day} + 0,
        };
    }
}, from MoverDateTimeStrIso, via {
    if ( $_ =~ $RE{time}{iso}{-keep} ) {
        return {
            year  => $2 + 0,
            month => $3 + 0,
            day   => $4 + 0,
        };
    }
}, from MoverDateTime, via {
    return {
        year      => $_->year + 0,
        month     => $_->month + 0,
        day       => $_->day + 0,
        time_zone => $_->time_zone,
    };
};

=head2 coerce MoverTimeHref
 From a string the MoverTimeStrHourFirst format
              HH:MM:SS, HH:MM:SS AM, HH:MM:SSPM
 from a DateTime.

=cut

#------Extract hms_am/pm from string
coerce MoverTimeHref, from MoverTimeStrHourFirst, via {
    if ( $_ =~ $HH_MM_SS_AMPM ) {
        return {
            year  => $+{year} + 0,
            month => $+{month} + 0,
            day   => $+{day} + 0,
        };
    }
}, from MoverDateTime, via {
    return {
        hour   => ( $_->hour   // 0 ) + 0,
        minute => ( $_->minute // 0 ) + 0,
        second => ( $_->second // 0 ) + 0,
        am_or_pm  => $_->am_or_pm,
        time_zone => $_->time_zone,
    };
};

#-------------------------------------------------------------------------------
#  Number to Day name, Day name to DateTime->day
#   and other conversions that can be used for date display.
#-------------------------------------------------------------------------------

=head2 Date Display Types
 Convenience types for easy conversion between many date element
 descriptions.
=cut

#------ List of strings that represent valid day names.
my @day_names =
    (qw/ monday tuesday wednesday thursday friday saturday sunday/);
my $i = 1;
Readonly my %NumberToDayName => map { $i++ => $_ } @day_names;

#------ List of strings that represent valid short day names.
my @day_names_short = (qw/ mon tue wed thu fri sat sun/);
$i = 1;
Readonly my %NumberToDayNameShort => map { $i++ => $_ } @day_names_short;

Readonly my %DayShortToDayLong =>
    map { $NumberToDayNameShort{$_} => $NumberToDayName{$_} }
    keys %NumberToDayNameShort;

#----- Various Day Names to WeekDay
Readonly my %DayToNumber => (
    monday    => '1',
    mon       => '1',
    mo        => '1',
    m         => '1',
    tuesday   => '2',
    tues      => '2',
    tue       => '2',
    tu        => '2',
    wednesday => '3',
    wed       => '3',
    we        => '3',
    w         => '3',
    thursday  => '4',
    thurs     => '4',
    thur      => '4',
    thu       => '4',
    th        => '4',
    friday    => '5',
    fri       => '5',
    fr        => '5',
    f         => '5',
    saturday  => '6',
    sat       => '6',
    sa        => '6',
    sunday    => '7',
    sun       => '7',
    su        => '7',
    s         => '7',
);

#-------------------------------------------------------------------------------
# Day Subtypes
#-------------------------------------------------------------------------------

=head2 MoverDayInt
 A single digit to represent a week day. 1 == Monday to 7 == Sunday

=cut 

subtype MoverDayInt, as SingleDigit, where { $_ > 0 && $_ < 8 },
    message { 'This digit,  ' . $_ . ' does not represent a day of week.' };

=head2 MoverDayName
 Day name.

=cut

subtype MoverDayName, as NonEmptyStr, where { $_ ~~ @day_names },
    message { $_ . ' Is not a valid day name.' };

=head2 MoverDayNameShort
 Short day name(The first three characters of the day name).

=cut

subtype MoverDayNameShort, as NonEmptyStr,
    where { $_ ~~ @day_names_short },
    message { $_ . ' Is not a valid short day name.' };

=head2 coerce MoverDayName
 from an integer (1 = monday,  to 7 = sunday)
 from day short name(first three characters, 'mon' to 'monday', 
 from a day name abbreviation, ie, to thursday from thurs or thur 
 thu or th.

=cut

coerce MoverDayName,
    from MoverDayInt,       via { $NumberToDayName{$_} },
    from MoverDayNameShort, via { $DayShortToDayLong{$_} },
    from NonEmptyStr,       via {
    $NumberToDayName{ $DayToNumber{ lc $_ } // $EMPTY_STR };
    },

    #------ Convert DateTime Object to day_name
    from MoverDateTime, via {
    lc( $_->day_name() );
    };

=head2 coerce MoverDayNameShort
 from a day name 
 from a day name abbreviation, ie, to thursday from thurs or thur 
 thu or th.
 from an integer (1 = monday,  to 7 = sunday)

=cut

coerce MoverDayNameShort, from MoverDayInt, via { $NumberToDayNameShort{$_} },

    #--- From day name,  day name short or abbr
    from NonEmptyStr,
    via { $NumberToDayNameShort{ $DayToNumber{ lc $_ } // $EMPTY_STR } },
    from MoverDateTime, via {
    lc( $_->day_abbr() );
    };

#-------------------------------------------------------------------------------
#  Month conversions
#-------------------------------------------------------------------------------

#------  Strings that can be used to represent a Month name
Readonly my @ValidMonthName => (
    qw /january february march april may june july august september october november december /
);

Readonly my @ValidMonthNameShort =>
    (qw /jan feb mar apr may jun jul aug sep oct nov dec /);

#----- Translates Number to its corresponding month name
$i = 1;
Readonly my %NumberToMonth => map { $i++ => $_ } @ValidMonthName;

#----- Translates Number to its corresponding short month name
$i = 1;
Readonly my %NumberToMonthShort => map { $i++ => $_ } @ValidMonthNameShort;

#----- Translate Month any name to Month Number
Readonly my %MonthToNumber => (
    january   => '1',
    jan       => '1',
    ja        => '1',
    february  => '2',
    feb       => '2',
    f         => '2',
    march     => '3',
    mar       => '3',
    april     => '4',
    apr       => '4',
    may       => '5',
    june      => '6',
    jun       => '6',
    july      => '7',
    jul       => '7',
    august    => '8',
    aug       => '8',
    au        => '8',
    september => '9',
    sept      => '9',
    sep       => '9',
    se        => '9',
    s         => '9',
    october   => '10',
    oct       => '10',
    oc        => '10',
    o         => '10',
    november  => '11',
    nov       => '11',
    no        => '11',
    n         => '11',
    december  => '12',
    dec       => '12',
    de        => '12',
    d         => '12',
);

=head2 MoverMonthInt
 Integer to represent a month. 1 => january etc.

=cut

subtype MoverMonthInt, as PositiveInt, where { $_ > 0 && $_ < 13 },
    message {"This digit $_ does not represent a month."};

=head2 MoverMonthName
 Month name in long format.

=cut

subtype MoverMonthName, as NonEmptyStr, where { $_ ~~ @ValidMonthName },
    message {"$_ is not a valid month name."};

=head2 coerce MoverMonthName
 from a month abbreviation ie. to august from aug  or au;
 from a month number (1 - 12) or a Datetime Object.

=cut

coerce MoverMonthName,

    #--- from Month Integer
    from MoverMonthInt, via {
    $NumberToMonth{$_} // $FAIL;
    },

    #--- from Month Abbreviation. Need the $FAIL to prevent false readings
    #    from integers.
    from NonEmptyStr, via {
    $NumberToMonth{ $MonthToNumber{ lc $_ } // $EMPTY_STR } // $FAIL;
    },

    #--- from DateTime Object
    from MoverDateTime, via {
    lc( $_->month_name() );
    };

=head2 MoverMonthNameShort
      Month name in short format(First three characters of the Month name).

=cut

subtype MoverMonthNameShort, as NonEmptyStr,
    where { $_ ~~ @ValidMonthNameShort },
    message {"$_ is not a valid short month name string."};

=head2 coerce MoverMonthNameShort
 from a long month name, a month number (1 - 12) 
 or from a Datetime Object.

=cut

coerce MoverMonthNameShort,

    #--- from an integer to Month Short name
    from MoverMonthInt, via { $NumberToMonthShort{$_} },

    # Convert a month name to its abbreviated name. january => 'jan'
    from NonEmptyStr, via {
    $NumberToMonthShort{ $MonthToNumber{ lc $_ } // $EMPTY_STR } // $FAIL;
    },

    #from DateTime Object to Short month Name (DateTime to 'jan')
    from MoverDateTime, via {
    lc( $_->month_abbr() );
    };

#-------------------------------------------------------------------------------
#  Create MoverDateTime Object from HashRef or strings
#-------------------------------------------------------------------------------
#----- Create DateTime object from various different formats.

=head2 coerce MoverDateTime
 Coerce MoverDateTime from various different input formats.
 DateTime ISO-8601 string, yyyymmdd string, 
 mmddyyyy string, ddmmyyyy string, 
 from any string using DateTime::Format::DateManip formatter
 and finally from HashRef, 
 in the above order of preference.
 More formatters will be added in the furure as required.

=cut

coerce MoverDateTime,

    #--- From Date Time ISO-8601 string
    from MoverDateTimeStrIso, via {
    ### Trying to Coerce MoverDateTime from Iso String: $_
    if ( $_ =~ $RE{time}{iso}{-keep} ) {
        try {
            return DateTime->new(
                year   => $2 + 0,
                month  => $3 + 0,
                day    => $4 + 0,
                hour   => ( $5 || 0 ) + 0,
                minute => ( $6 || 0 ) + 0,
                second => ( $7 || 0 ) + 0,
            );
        }
        catch {
            $log->error(
                'Unable to coerce MoverDateTimeStrIso to DateTime!  ' . "\n"
                    . $_ );
            $FAIL;
        }
    }
    },

    #--- From yyy-mm-dd string
    from MoverDateStrYearFirst, via {
    ### Trying to Coerce MoverDateTime from yyyymmdd regex:  $_
    if ( $_ =~ $YYYY_MM_DD_REGEX ) {
        try {
            return DateTime->new(
                year  => $+{year} + 0,
                month => $+{month} + 0,
                day   => $+{day} + 0,
            );
        }
        catch {
            $log->error(
                'Unable to coerce MoverDateStrYearFirst to DateTime!  ' . "\n"
                    . $_ );
            $FAIL;
        }
    }
    },

    #--- From mm-dd-yyyy string
    from MoverDateStrMonthFirst, via {
    ### Trying to Coerce MoverDateTime from mmddyyyy regex:  $_
    if ( $_ =~ $MM_DD_YYYY_REGEX ) {
        try {
            return DateTime->new(
                year  => $+{year} + 0,
                month => $+{month} + 0,
                day   => $+{day} + 0,
            );
        }
        catch {
            $log->error(
                      'Unable to coerce MoverDateStrMonthFirst to DateTime!  '
                    . "\n"
                    . $_ );
            $FAIL;
        }
    }

    },

    #--- From dd-mm-yyyy string
    from MoverDateStrDayFirst, via {
    ### Trying to Coerce MoverDateTime from ddmmyyyy regex:  $_
    if ( $_ =~ $DD_MM_YYYY_REGEX ) {
        try {
            return DateTime->new(
                year  => $+{year} + 0,
                month => $+{month} + 0,
                day   => $+{day} + 0,
            );
        }
        catch {
            $log->error(
                'Unable to coerce MoverDateStrDayFirst to DateTime!  ' . "\n"
                    . $_ );
            $FAIL;
        };
    }
    },

    #---- Try DateTime::Format::DateManip
    from NonEmptySimpleStr, via {
    try {
        require DateTime::Format::DateManip;
        ### Date Manip to parse string : $_
        my $dt = DateTime::Format::DateManip->parse_datetime( crunch($_) );
        ### Date Manip Parser Returning :  blessed($dt) // $EMPTY
        return $dt;
    }
    catch {
        $log->error( 'Date Manip failed! ' . "\n" . $_ );
        $FAIL;
    };
    },

    #--- From MoverDateTimeHref
    from MoverDateTimeHref, via {
    ### Trying to Coerce MoverDateTime from MoverDateTimeHref :  $_
    try {
        return DateTime->new(
            year   => ( $_->{year}   || 0 ) + 0,
            month  => ( $_->{month}  || 0 ) + 0,
            day    => ( $_->{day}    || 0 ) + 0,
            hour   => ( $_->{hour}   || 0 ) + 0,
            minute => ( $_->{minute} || 0 ) + 0,
            second => ( $_->{second} || 0 ) + 0,
        );
    }
    catch {
        ### Unable to coerce to MoverDateTime from HashRef : $_
        $log->error(
            'Unable to coerce MoverDateTimeHref to DateTime!  ' . "\n" . $_ );
        $FAIL;
    };
    },

    #--- From HashRef
    from MoverDateHref, via {
    ### Trying to Coerce MoverDateTime from MoverDateHref :  $_
    try {
        return DateTime->new(
            year  => ( $_->{year}  || 0 ) + 0,
            month => ( $_->{month} || 0 ) + 0,
            day   => ( $_->{day}   || 0 ) + 0
        );
    }
    catch {
        ### Failed to coerce from MoferDatHref : $_
        $log->error(
            'Unable to coerce MoverDateHref to DateTime!  ' . "\n" . $_ );
        $FAIL;
    };
    };

#-------------------------------------------------------------------------------
#  END
#-------------------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

# ABSTRACT: Mover Moose Types for Dates and Times

=head1 NAME

Mover::Date::Types -  Mover MooseX types for dates and times.

=head1 SYNOPSIS


#--- Imported Mover Types
use Mover::Types qw/
          MoverDateTime

          MoverDateTimeRecent

          MoverDateTimeStrIso

          MoverDateStrYearFirst

          MoverDateStrMonthFirst

          MoverDateStrDayFirst

          MoverTimeStrHourFirst

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

          MoverDateUnit

          MoverBeforeOrAfter

          /;

    #----- Coerce a DateTime from a natural string
    my $DateTime = to_MoverDateTime(q/tomorrow at 10pm/);

    say 'Date is ' . $DateTime->mdy() . ' at ' . $DateTime->hms; 

    #----- Coerce a DateTime from a year first date string
    $DateTime = to_MoverDateTime(q/1999-12-31/);   # DateTime Obj

    say 'Party like its ' . $DateTime->year() ;    # 1999
    
    #----- Create a DateTime from a string containing a date
    my $date_in_string = q{what day  will Christmas be on 12-25-2013 this year? };

    if($mmddyyyy = to_MoverDateStrMonthFirst($date_in_string){
            my $date_hash_ref = to_MoverDateHash($date_in_string);
            say "Yes, it is on $mmddyyyy for the year " .      #12/25/2013
            $date_hash_ref->{year};                            # 2013

        # Or if you really want; Create a DateTime from a Hashref with
        # DateTime data
        my $ChrstmasDt = to_MoverDateTime($date_hash_ref);     # DateTime Object

        say 'Which would be a '. to_MoverDayNameShort($ChristmasDt); # 'wed'
    }

    #----- Useful ways for displaying DateTime data
    say 'The Month is ' . to_MoverMonthName($ChristmasDt)

        if (is_MoverDateTime($ChritsmasDt));
    
    # Given an integer,  tell me what day of week it is?
    # Monday is 1, to Sunday == 6;
    # Careful how you use this one

    say 'The day is '. to_MoverDayName(3); # 'wednesday'

    say 'The month is '. to_MoverMonthName(7); # 'july'


=head1 DESCRIPTION
   Used for creating and or validating various date types, date elements. It
   is particularly useful for my Mover app and ist modules.


=head1 SEE ALSO

=over

 
=item *
 
 L<Convert::Input::To::DateTime>

=item *
 
 L<MooseX::Types>
  
=item *
 
 L<DateTime>
  
=item *
 
 L<Regexp::Common::time>
  
=item *

 L<DateTime::Format::DateManip>

=back

=cut




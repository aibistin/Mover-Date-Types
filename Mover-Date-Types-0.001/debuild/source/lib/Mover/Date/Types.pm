#===============================================================================
#         FILE: Mover/Date/Types.pm
#
#  DESCRIPTION: Mover Moose Types for Dates and Times
#
#       AUTHOR: Austin Kenny (), aibistin.cionnaith@gmail.com
#      CREATED: 02/20/2013 11:20:37 PM
#
#===============================================================================
use Modern::Perl q/2012/;
use autodie;

package Mover::Date::Types;

our $VERSION = q/0.001/;    # from D Golden blog
$VERSION = eval $VERSION;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

with 'Convert::Input::To::DateTime';

use List::MoreUtils qw/firstidx/;
use String::Util qw/trim crunch fullchomp hascontent/;
use Regexp::Common qw/time/;
use Smart::Comments -ENV;
use DateTime;
use Try::Tiny;
use MooseX::Types::Moose qw(
    Str
    Int
    HashRef
    ArrayRef
    Object
    Value
);

use MooseX::Types::Common::Numeric qw(
    PositiveInt PositiveOrZeroInt
    SingleDigit);
use MooseX::Types::Common::String qw( NonEmptyStr NonEmptySimpleStr);

use MooseX::Types -declare => [
    qw(
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
        )
];

#-------------------------------------------------------------------------------
#  Constants
#-------------------------------------------------------------------------------
use Readonly;

Readonly my $YES       => 1;
Readonly my $TRUE      => 1;
Readonly my $NO        => 0;
Readonly my $FALSE     => 0;
Readonly my $FAIL      => undef;
Readonly my $EMPTY_STR => q//;
Readonly my $EMPTY_BOX => q/<empty>/;

#------ Mover Date Specific constants
Readonly my $DEFAULT_LANG => 'en';
Readonly my $UTC_TZ       => 'UTC';
Readonly my $NEW_YORK_TZ  => 'America/New_York';
Readonly my $LOCAL_TZ     => $NEW_YORK_TZ;
Readonly my $FLOATING_TZ  => 'floating';
Readonly my $MORNING      => '06';
Readonly my $AFTERNOON    => '13';
Readonly my $EVENING      => '17';
Readonly my $F_SLASH      => '/';
Readonly my $B_SLASH      => '\\';
Readonly my $DASH         => '-';
Readonly my $DOT          => '.';

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

# yyyy-mm-dd,  yyyy/mm/dd yyyy.mm.dd
Readonly my $YYYY_MM_DD_REGEX =>
    qr/$year_rx$date_seperator$month_rx$date_seperator$day_rx/;

#  qr/(?<year>[0-9][0-9][0-9][0-9])[\-\/\.](?<month>[0-1]?[0-9])[\-\/\.](?<day>[0-3]?[0-9])/;

# mm-dd-yyyy,  mm/dd/yyyy mm.dd.yyyy
Readonly my $MM_DD_YYYY_REGEX =>
    qr/$month_rx$date_seperator$day_rx$date_seperator$year_rx/;

#  qr/(?<month>[0-1]?[0-9])[\-\/\.](?<day>[0-3]?[0-9])[\-\/\.](?<year>[0-9][0-9][0-9][0-9])/;

# dd-mm-yyyy,  dd/mm/yyyy dd.mm.yyyy
Readonly my $DD_MM_YYYY_REGEX =>
    qr/$day_rx$date_seperator$month_rx$date_seperator$year_rx/;

#  qr/(?<day>[0-3]?[0-9])(?<month>[0-1]?[0-9])[\-\/\.][\-\/\.](?<year>[0-9][0-9][0-9][0-9])/;

#----- Time Regex's
my $hour_rx             = qr/(?<hour>[0-2][0-9])/;
my $minute_rx           = qr/(?<minute>[0-6][0-9])/;
my $second_rx           = qr/(?<second>[0-6][0-9])/;
my $maybe_am_or_pm_rx   = qr/(?<am_or_pm>[aApP][mM])?/;
my $time_seperator      = qr/[:\.]/;
my $maybe_space_rx      = qr/\s?/;
my $maybe_space_or_t_rx = qr/[\s|t|T]?/;

#------ A little similar
# mm-dd-yyyy HH:MM:SS AM mm/dd/yyyy HH:MM:SSAM mm/dd/yyyy HH:MM:SS
Readonly my $MM_DD_YYYY_HH_MM_SS_AMPM =>
    qr/$month_rx$date_seperator$day_rx$date_seperator$year_rx$maybe_space_or_t_rx
$hour_rx$time_seperator$minute_rx$time_seperator$second_rx$maybe_space_rx$maybe_am_or_pm_rx/;

#qr/(?<month>\d\d)[\-\/](?<day>\d\d)[\-\/](?<year>\d\d\d\d)\s(?<hour>\d\d):(?<minute>\d\d):?(?<second>\d\d)?\s?(?<am_or_pm>[aApP][mM])?/;

# HH:MM:SS,  HH:MM:SS AM,  HH:MM:SSPM
Readonly my $HH_MM_SS_AMPM =>
    qr/$hour_rx$time_seperator$minute_rx$time_seperator$second_rx$maybe_space_rx$maybe_am_or_pm_rx/;

#  qr/(?<hour>\d\d):(?<minute>\d\d):(?<second>\d\d)\s?(?<am_or_pm>[aApP][mM])?/;

#-------------------------------------------------------------------------------
#  DateTime Types
#-------------------------------------------------------------------------------
class_type 'DateTime';

subtype MoverDateTime, as Object, where {
    $_->isa('DateTime');
}, message {
    ( ( try {$_} ) // '<No DateTime>' ) . ' is not a DateTime Object!';
};

subtype MoverDateTimeRecent, as MoverDateTime, where {
    ( $_->year() > $MIN_MOVER_YEAR ) && ( $_->year() < $MAX_MOVER_YEAR );
}, message {
    ( ( try { $_->year() } ) // '<No DateTime>' )
        . ' is outside our date range!';
};

coerce MoverDateTimeRecent, from Value,
    via { Convert::Input::To::DateTime->convert_to_datetime($_) };

#-------------------------------------------------------------------------------
#  Time zone params
#-------------------------------------------------------------------------------

subtype MoverUtcTz, as NonEmptyStr, where {
    $_ eq 'UTC';
}, message {'Not a valid UTC time string.'};

coerce MoverUtcTz, from NonEmptyStr, via { uc $_; };

subtype MoverDateUnit, as NonEmptyStr, where { $_ =~ /^$DATE_UNIT_REGEX$/ };

coerce MoverDateUnit, from NonEmptyStr, via {
    if ( $_ =~ /DATE_UNIT_REGEX/i ) {
        return lc( $+{date_unit} );
    }
};

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

subtype MoverDateStrYearFirst, as NonEmptyStr,
    where { $_ =~ /^$RE{time}{ymd}$/ },
    message {"Invalid format for Year First Date string: $_"};

coerce MoverDateStrYearFirst,

    #--- Get ymd string from DateTime Object
    from 'DateTime', via { $_->ymd() },

    #--- Get ymd string from String
    from NonEmptyStr, via {
    $_ =~ $YYYY_MM_DD_REGEX;
    $+{year} . $F_SLASH . $+{month} . $F_SLASH . $+{day};
    };

#--- Validate USA style date

subtype MoverDateStrMonthFirst,
    as NonEmptyStr,
    where { $_ =~ /^$RE{time}{mdy}$/; },
    message {"Invalid format for Month First Date string: $_"};

coerce MoverDateStrMonthFirst,

    #--- Get mdy string from DateTime Object
    from 'DateTime', via { $_->mdy() },

    #--- Get mdy string from string
    from NonEmptyStr, via {
    $_ =~ $MM_DD_YYYY_REGEX;
    ### MMDDYYYY Coersion matched : $+{month}.$+{day}.$+{year}
    $+{month} . $F_SLASH . $+{day} . $F_SLASH . $+{year};
    };

#--- Validate European style date

subtype MoverDateStrDayFirst, as NonEmptyStr,
    where {/^$RE{time}{dmy}$/},
    message {"Invalid format for Day First Date string: $_"};

coerce MoverDateStrDayFirst,

    #--- Get euro style dmy string from Datetime
    from 'DateTime', via { $_->dmy() },

    #--- Get euro style dmy string from string
    from NonEmptyStr, via {
    $_ =~ $DD_MM_YYYY_REGEX;
    $+{day} . $F_SLASH . $+{month} . $F_SLASH . $+{year};
    };

subtype MoverDateTimeStrIso, as NonEmptyStr,
    where {/^$RE{time}{iso}{-keep}$/},
    message {"Invalid format for Iso-8601 Date string: $_"};

coerce MoverDateTimeStrIso, from NonEmptyStr, via {
    if ( $_ =~ $RE{time}{iso}{-keep} ) { return $1; }
};

#---------------Times

subtype MoverTimeStrHourFirst, as NonEmptyStr,
    where {/^$RE{time}{hms}$/},
    message {"Invalid format for Hour First Time string: $_"};

coerce MoverTimeStrHourFirst, from 'DateTime', via { $_->hms() },

    #--- Extract hhmmss from string
    from NonEmptyStr, via {
    if ( $_ =~ $RE{time}{hms}{-keep} ) { return $1; }
    };

#-------------------------------------------------------------------------------
#  Date Extraction To Hashref Types
#-------------------------------------------------------------------------------
#------ Date expressed as Hashref

subtype MoverDateHref, as HashRef, where {
    defined $_->{year} && defined $_->{month} && defined $_->{day};
}, message {"Invalid format for Date Hashref $_"};

#------ Time expressed as Hashref

subtype MoverTimeHref, as HashRef, where {
           defined $_->{hour}
        && defined $_->{minute}
        && exists $_->{second}
        && exists $_->{am_or_pm};
}, message {"Invalid format for Time Hashref $_"};

subtype MoverDateTimeHref, as HashRef, where {
           defined $_->{year}
        && defined $_->{month}
        && defined $_->{day}
        && defined $_->{hour}
        && defined $_->{minute}
        && exists $_->{second};
}, message {"Invalid format for Date Time Hashref $_"};

coerce MoverDateHref, from MoverDateStrYearFirst, via {
    if ( $_ =~ $YYYY_MM_DD_REGEX ) {
        return {
            year  => $+{year},
            month => $+{month},
            day   => $+{day},
        };
    }
}, from MoverDateStrMonthFirst, via {
    if ( $_ =~ $MM_DD_YYYY_REGEX ) {
        return {
            year  => $+{year},
            month => $+{month},
            day   => $+{day},
        };
    }
}, from MoverDateStrDayFirst, via {

    if ( $_ =~ $DD_MM_YYYY_REGEX ) {
        return {
            year  => $+{year},
            month => $+{month},
            day   => $+{day},
        };
    }
};

#------Extract hms_am/pm from string
coerce MoverTimeHref, from MoverTimeStrHourFirst, via {$HH_MM_SS_AMPM};

#--- More detailed ISO datetime string extraction using Regexp Common
#    Time ISO-8601
coerce MoverDateTimeHref, from MoverDateTimeStrIso, via {
    if ( $_ =~ $RE{time}{iso}{-keep} ) {
        return {
            year   => $2,
            month  => $3,
            day    => $4,
            hour   => $5 || 0,
            minute => $6 || 0,
            second => $7 || 0,
        };
    }
};

#-------------------------------------------------------------------------------
#  Number to Day name, Day name to DateTime->day
#   and other conversions that can be used for date display.
#-------------------------------------------------------------------------------

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

subtype MoverDayInt, as SingleDigit, where { $_ > 0 && $_ < 8 },
    message { 'This digit,  ' . $_ . ' does not represent a day of week.' };

subtype MoverDayName, as NonEmptyStr, where { $_ ~~ @day_names },
    message { $_ . ' Is not a valid day name.' };

subtype MoverDayNameShort, as NonEmptyStr,
    where { $_ ~~ @day_names_short },
    message { $_ . ' Is not a valid short day name.' };

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

subtype MoverMonthInt, as PositiveInt, where { $_ > 0 && $_ < 13 },
    message {"This digit $_ does not represent a month."};

subtype MoverMonthName, as NonEmptyStr, where { $_ ~~ @ValidMonthName },
    message {"$_ is not a valid month name."};

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

subtype MoverMonthNameShort, as NonEmptyStr,
    where { $_ ~~ @ValidMonthNameShort },
    message {"$_ is not a valid short month name string."};

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

coerce MoverDateTime,

    #--- From Date Time ISO-8601 string
    from MoverDateTimeStrIso, via {
    ### Trying to Coerce MoverDateTime from Iso String: $_
    if ( $_ =~ $RE{time}{iso}{-keep} ) {
        try {
            DateTime->new(
                year   => $2,
                month  => $3,
                day    => $4,
                hour   => $5 || 0,
                minute => $6 || 0,
                second => $7 || 0,
            );
        };
    }
    },

    #--- From yyy-mm-dd string
    from MoverDateStrYearFirst, via {
    ### Trying to Coerce MoverDateTime from yyyymmdd regex:  $_
    if ( $_ =~ $YYYY_MM_DD_REGEX ) {
        try {
            DateTime->new(
                year  => $+{year},
                month => $+{month},
                day   => $+{day},
            );
        };
    }
    },

    #--- From mm-dd-yyyy string
    from MoverDateStrMonthFirst, via {
    ### Trying to Coerce MoverDateTime from mmddyyyy regex:  $_
    if ( $_ =~ $MM_DD_YYYY_REGEX ) {
        try {
            DateTime->new(
                year  => $+{year},
                month => $+{month},
                day   => $+{day},
            );
        };
    }

    },

    #--- From dd-mm-yyyy string
    from MoverDateStrDayFirst, via {
    ### Trying to Coerce MoverDateTime from ddmmyyyy regex:  $_
    if ( $_ =~ $DD_MM_YYYY_REGEX ) {
        try {
            DateTime->new(
                year  => $+{year},
                month => $+{month},
                day   => $+{day},
            );
        };
    }

    },

    #---- Try DateTime::Format::DateManip
    NonEmptySimpleStr, via {
    ### Trying to Coerce MoverDateTime Using DateManip: $_
    try {
        require DateTime::Format::DateManip;

        #--- Date Manip Parsed string : $_
        DateTime::Format::DateManip->parse_datetime($_);
    }
    catch {
        say 'Cannot find DateTime::Format::DateManip...';
    };
    },

    #--- From HashRef
    from MoverDateHref, via {
    ### Trying to Coerce MoverDateTime from HashRef: $_
    try {
        DateTime->new(%$_);
    };
    };

#
#-------------------------------------------------------------------------------
#  Private Methods
#-------------------------------------------------------------------------------
sub _yyyy_mm_dd_regex {
    my $self = shift if ref $_[0];
    return $YYYY_MM_DD_REGEX;
}

sub _mm_dd_yyyy_regex {
    my $self = shift if ref $_[0];
    return $MM_DD_YYYY_REGEX;
}

sub _dd_mm_yyyy_regex {
    my $self = shift if ref $_[0];
    return $DD_MM_YYYY_REGEX;
}

#-------------------------------------------------------------------------------
#  END
#-------------------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 NAME

Mover::Date::Types - Mover Moose Types for Dates and Times

=head1 VERSION

version 0.001

=head1 SYNOPSIS

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

    my $DateTime = to_MoverDateTime(q/tomorrow at 10pm/);
    say 'Date is ' . $DateTime->mdy() . ' at ' . $DateTime->hms; 

    $DateTime = to_MoverDateTime(q/1999-12-31/);   # DateTime Obj
    say 'Party like its ' . $DateTime->year() ;    # 1999
    
    my $date_in_string = q{what day  will Christmas be on 12-25-2013 this year? };
    if($mmddyyyy = to_MoverDateStrMonthFirst($date_in_string){
            my $date_hash_ref = to_MoverDateHash($date_in_string);
            say "Yes, it is on $mmddyyyy for the year " .      #12/25/2013
            $date_hash_ref->{year};                            # 2013
        # Or if you really want.
        my $ChrstmasDt = to_MoverDateTime($date_hash_ref);     # DateTime Object
        say 'Which would be a '. to_MoverDayNameShort($ChristmasDt); # 'wed'
    }

    say 'The Month is ' . to_MoverMonthName($ChristmasDt)
        if (is_MoverDateTime($ChritsmasDt));
    
    # Given an integer,  tell me what day of week it is?
    # Monday is 1, to Sunday == 6;
    say 'The day is '. to_MoverDayName(3); # 'wednesday'

    say 'The month is '. to_MoverMonthName(7); # 'july'

=head1 FUNCTIONS

=head2 MoverDateTime
 A 'DateTime' object for the Mover project.

=head2 MoverDateTimeRecent
 A 'DateTime' object that is not too far into the past or the future.
 Can be coerced from a string or hash using the role
 Convert::Input::To::DateTime->convert_to_datetime()

=head2 MoverUtcTz
 UTC time zone.
 Can be coerced from any string that contains 'UTC' 

=head2 MoverDateUnit
 String to represent date units,  year, month, week, day, hour, minute.
 Can be coerced from any string that contains the first one of these to 
 be found using regex.

=head2 MoverBeforeOrAfter
 String to represent before_or_after, a particular date.
 q/before/ or q/after/
 Can be coerced from any string that contains before or after.

=head2 MoverDateStrYearFirst
 A string to represent a date with the year first
 YYYY/MM/DD corresponding to Regex Commom 
 $RE{time}{ymd}

=head2 MoverDateStrMonthFirst
 A string to represent a date with the month first
 MM/DD/YYYY corresponding to Regex Commom 
 $RE{time}{mdy}

=head2 MoverDateStrDayFirst
 A string to represent a date with the day first
 (European style.)
 DD/MM/YYYY corresponding to Regex Commom 
 $RE{time}{dmy}

=head2 coerce MoverDateStrYearFirst MoverDateStrMonthFirst MoverDateStrDayFirst
      from any string containing a date in one of these formats.

=head2 MoverDateTimeStrIso (ISO-8601)
 A string to represent a date in ISO-8601 format
 Corresponding to Regex Commom 
 $RE{time}{iso}{-keep}
 $1 = full match, $2 = year, $3 = month, 
 $4 = day .. $7 = second.

=head2 coerce MoverDateTimeStrIso 
 from any string containing a date in ISO-1861 format
 using $RE{time}{iso}{-keep}.

=head2 MoverTimeStrHourFirst
 A string to represent a time in HH:MM:SS format
 Corresponding to Regex Common 
 $RE{time}{hms}

=head2 coerce MoverTimeStrHourFirst
 from 'DateTime' Object, 
 or from a string containing hms using $RE{time}{hms}{-keep}

=head2 MoverDateHref
 Date represented by as HashRef.
 {
   year  => $year, 
   month => $month, 
   day   => $day, 
 }

=head2 MoverTimeHref
 Time represented by as HashRef.
 {
   hour    => $hour, 
   minute  => $minute, 
   second  => $second, 
   am_or_pm => q/am/
 }

=head2 MoverDateTimeHref
 Date Time expressed as Hashref
 {
   year    => $year, 
   month   => $month, 
   day     => $day, 
   hour    => $hour, 
   minute  => $minute, 
   second  => $second, 
   am_or_pm => q/am/
  }

=head2 coerce MoverDateHref
 From a string containing a date, gives priority to yyyymmdd,
 then mmddyyyy followed by Euro style ddmmyyyy then ISO-8601
 date time format.

=head2 MoverDayInt
 A single digit to represent a week day. 1 == Monday to 7 == Sunday

=head2 MoverDayName
 Day name.

=head2 MoverDayNameShort
 Short day name(The first three characters of the day name).

=head2 coerce MoverDayName
 from an integer (1 = monday,  to 7 = sunday)
 from day short name(first three characters, 'mon' to 'monday', 
 from a day name abbreviation, ie, to thursday from thurs or thur 
 thu or th.

=head2 coerce MoverDayNameShort
 from a day name 
 from a day name abbreviation, ie, to thursday from thurs or thur 
 thu or th.
 from an integer (1 = monday,  to 7 = sunday)

=head2 MoverMonthInt
 Integer to represent a month. 1 => january etc.

=head2 MoverMonthName
 Month name in long format.

=head2 coerce MoverMonthName
 from a month abbreviation ie. to august from aug  or au;
 from a month number (1 - 12) or a Datetime Object.

=head2 MoverMonthNameShort
      Month name in short format(First three characters of the Month name).

=head2 coerce MoverMonthNameShort
 from a long month name, a month number (1 - 12) 
 or from a Datetime Object.

=head2 coerce MoverDateTime
 Coerce MoverDateTime from various different input formats.
 DateTime ISO-8601 string, yyyymmdd string, 
 mmddyyyy string, ddmmyyyy string, 
 from any string using DateTime::Format::DateManip formatter
 and finally from HashRef, 
 in the above order of preference.
 More formatters will be added in the furure as required.

=head2 Date Display Types
 Convenience types for easy conversion between many date element
 descriptions.

=head1 NAME

Mover::Date::Types -  Mover MooseX types for dates and times.

=head1 DESCRIPTION
   Used for creating and or validating various date types, date elements. It
   is particularly useful for my Mover app and ist modules.

=head1 SEE ALSO

=over

=item *

 L<MooseX::Types>

=item *

 L<DateTime>

=item *

 L<Regexp::Common::time>

=item *

 L<DateTime::Format::DateManip>

=back

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/aibistin/mover-date-types/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/aibistin/mover-date-types>

  git clone git://github.com/aibistin/mover-date-types.git

=head1 AUTHOR

Austin Kenny <aibistin.cionnaith@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Austin Kenny.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__

# ABSTRACT: Mover Moose Types for Dates and Times





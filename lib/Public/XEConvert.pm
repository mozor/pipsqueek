package Handlers::Public::XEConvert;
#
# This package handles currency conversion
#
# The following were supported at time of writing:
# AED AFA ALL AMD ANG AOA ARS ATS AUD AWG AZM BAM 
# BBD BDT BEF BGL BHD BIF BMD BND BOB BRL BSD BTN BWP BYR BZD 
# CAD CDF CHF CLP CNY COP CRC CUP CVE CYP CZK
# DEM DJF DKK DOP DZD 
# EEK EGP ERN ESP ETB EUR
# FIM FJD FKP FRF 
# GBP GEL GGP GHC GIP GMD GNF GRD GTQ GYD
# HKD HNL HRK HTG HUF 
# IDR IEP ILS IMP INR IQD IRR ISK ITL 
# JEP JMD JOD JPY
# KES KGS KHR KMF KPW KRW KWD KYD KZT
# LAK LBP LKR LRD LSL LTL LUF LVL LYD
# MAD MDL MGF MKD MMK MNT MOP MRO MTL MUR MVR MWK MXN MYR MZM 
# NAD NGN NIO NLG NOK NPR NZD
# OMR
# PAB PEN PGK PHP PKR PLN PTE PYG 
# QAR
# ROL RUR RWF
# SAR SBD SCR SDD SEK SGD SHP SIT SKK SLL SOS SPL SRG STD SVC SYP SZL
# THB TJS TMM TND TOP TRL TTD TVD TWD TZS 
# UAH UGX USD UYU UZS 
# VAL VEB VND VUV 
# WST 
# XAF XAG XAU XCD XDR XOF XPD XPF XPT 
# YER YUM 
# ZAR ZMK ZWD
#
use base 'PipSqueek::Handler';
use strict;
use LWP::Simple;

sub get_handlers 
{
	my $self = shift;
	return {
		'public_money' => \&public_convert,
	};
}


sub get_description 
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "Converts between currencies.  Most common are USD, EUR, GBP, JPY, CAD, DEM" if( /public_money/ );
	}
}


sub get_usage
{ 
	my $self = shift;
	my $type = shift;
	foreach ($type) {
		return "!money <amount> <from> <to>" if( /public_money/ );
	}
}


sub public_convert
{
	my $bot = shift;
	my $event = shift;
	my $umgr = shift;

	my ($amount,$from,$to) = split(/\s+/,$event->param('msg'));
	
	unless( defined($amount) && defined($from) && defined($to) ) {
		return $bot->chanmsg("Invalid parameters.");
	}
	
	if( $amount =~ /[^0-9\.]/ || $from =~ /[^A-Za-z]/ || $to =~ /[^A-Za-z]/ || length($from) != 3 || length($to) != 3 ) {
		return $bot->chanmsg("Invalid parameters.");
	}

	$from = uc($from); $to = uc($to);

	my $url = "http://www.xe.com/ucc/convert.cgi?Amount=$amount&From=$from&To=$to&Header=PipSqueek&Footer=PipSqueek";
	$url = URI::URL->new($url);

	my $results = get($url);
	
	$results =~ /1 $from = ([0-9\.\,]+) /;
	my $factor = $1;
	$factor =~ s/\,//g;

	$a = $amount;
	$b = $amount * $factor;

	$bot->chanmsg("$a $from = $b $to");
}


1;


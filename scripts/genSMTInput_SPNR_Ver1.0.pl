#! /usr/bin/perl

use strict 'vars';
use strict 'refs';
use strict 'subs';

use POSIX;

use Cwd;

### Revision History : Ver 1.0 #####
# 2020-12-08 V1.0 : Initial Release

### Pre-processing ########################################################
my $ARGC        = @ARGV;
my $workdir     = getcwd();
my $outdir      = "$workdir/inputsSMT";
my $infile      = "";

my $BoundaryCondition = 0; # 0: Fixed, 1: Extensible
my $SON = 1;               # 0: Disable, 1: Enable
my $DoublePowerRail = 0;   # 0: Disable, 1: Enable
my $MM_Parameter = 4;      # 3: Maximum Number of MetalLayer
my $EXT_Parameter = 0;     # 0 only
my $BCP_Parameter = 1;     # 0: Disable 1: Enable BCP(Default)

my $MAR_Parameter = 1;     # ARGV[1], Minimum Area 1: (Default), Integer
my $EOL_Parameter = 1;     # ARGV[2], End-of-Line  1: (Default), Integer
my $VR_Parameter = 1.5;    # ARGV[3], VIA sqrt(2)=1.5 : (Default), Floating
my $PRL_Parameter = 1;     # ARGV[4], Parallel Run-length 1: (Default). Integer
my $SHR_Parameter = 1;     # ARGV[5], Step Heights 1: (Default), Integer
my $MPL_Parameter = 3;     # ARGV[6], 3: (Default) Minimum Pin Opening
my $XOL_Mode = 2;		   # ARGV[7], 0: SDB, 1:DDB, 2:(Default)SDB/DDB mixed
my $NDE_Parameter = 0;     # ARGV[8], 0: Disable(Default) 1: Enable NDE
my $Partition_Parameter = 0; # ARGV[9], 0: Disable(Default) 1. Cell Partitioning
my $ML_Parameter = 5;	   # ARGV[10], 5: (Default) Min Metal Length for avoiding adjacent signal routing (only works with special net setting)
my $Local_Parameter = 0;   # ARGV[11], 0: Disable(Default) 1: Localization for Internal node within same diffusion region
my $tolerance_Parameter = 1;   # ARGV[12], Localization Offset Margin, Integer
my $BS_Parameter = 0;      # ARGV[13], 0: Disable(Default) 1: Enable BS(Breaking Symmetry)
my $objpart_Parameter = 0; # ARGV[14], 0: Disable(Default) 1. Objective Partitioning

my $XOL_Parameter = 2;     # Depends on XOL_Mode
if($XOL_Mode == 0){
	$XOL_Parameter = 2;
}
else{
	$XOL_Parameter = 4;
}

my @mapTrack = ([0,5], [1,4], [2,4], [3,1], [4,1], [5,0]);  # Placement vs. Routing Horizontal Track Mapping Array [Placement, Routing]
my @numContact = ([1,2], [2,2], [3,2]);  # Number of Routing Contact for Each Width of FET
my %h_mapTrack = ();
my %h_RTrack = ();
my %h_numCon = ();
for my $i(0 .. $#mapTrack){
	$h_mapTrack{$mapTrack[$i][1]} = 1;
	$h_RTrack{$mapTrack[$i][0]} = $mapTrack[$i][1];
}
for my $i(0 .. $#numContact){
	$h_numCon{$numContact[$i][0]} = $numContact[$i][1] - 1;
}

if ($ARGC != 15) {
    print "\n*** Error:: Wrong CMD";
    print "\n   [USAGE]: ./PL_FILE [inputfile_pinLayout] [MAR] [EOL] [VR] [PRL] [SHR] [MPO] [DBMode] [FST] [CellPartition] [CrosstalkML] [Localization] [Tolerance] [BreakingSymmetry] [ObjPartition]\n\n";
    exit(-1);
} else {
    $infile = $ARGV[0];
	$MAR_Parameter = $ARGV[1];
	$EOL_Parameter = $ARGV[2];
	$VR_Parameter = $ARGV[3];
	$PRL_Parameter = $ARGV[4];
	$SHR_Parameter = $ARGV[5];
	$MPL_Parameter = $ARGV[6];
	$XOL_Mode = $ARGV[7];
	$NDE_Parameter = $ARGV[8];
	$Partition_Parameter = $ARGV[9];
	$ML_Parameter = $ARGV[10];
	$Local_Parameter = $ARGV[11];
	$tolerance_Parameter = $ARGV[12];
	$BS_Parameter = $ARGV[13];
	$objpart_Parameter = $ARGV[14];

    if ($MAR_Parameter == 0){
        print "\n*** Disable MAR (When Parameter == 0) ***\n";
    }
    if ($EOL_Parameter == 0){
        print "\n*** Disable EOL (When Parameter == 0) ***\n";
    }     
    if ( $VR_Parameter == 0){
        print "\n*** Disable VR (When Parameter == 0) ***\n";
    }
    if ( $PRL_Parameter == 0){
        print "\n*** Disable PRL (When Parameter == 0) ***\n";
    }
    if ( $SHR_Parameter < 2){
        print "\n*** Disable SHR (When Parameter <= 1) ***\n";
    }
    if ( $Local_Parameter == 0){
        print "\n*** Disable Localization (When Parameter == 0) ***\n";
    }
    if ( $Partition_Parameter == 0){
        print "\n*** Disable Cell Partitioning (When Parameter == 0) ***\n";
    }
    if ( $objpart_Parameter == 0){
        print "\n*** Disable Objective Partitioning (When Parameter == 0) ***\n";
    }
    if ( $BS_Parameter == 0){
        print "\n*** Disable Breaking Symmetry (When Parameter == 0) ***\n";
    }
    if ( $NDE_Parameter == 0){
        print "\n*** Disable FST (When Parameter == 0) ***\n";
    }
}
my $tolerance = $tolerance_Parameter;

if (!-e "./$infile") {
    print "\n*** Error:: FILE DOES NOT EXIST..\n";
    print "***         $workdir/$infile\n\n";
    exit(-1);
} else {
    print "\n";
    print "a   Version Info : 1.0 Initial Release\n";
    print "a        Design Rule Parameters : [MAR = $MAR_Parameter , EOL = $EOL_Parameter, VR = $VR_Parameter, PRL = $PRL_Parameter, SHR = $SHR_Parameter]\n";
    print "a        Parameter Options : [MPO = $MPL_Parameter], [Localization = $Local_Parameter (T$tolerance)]\n";
	print "a	                        [Cell Partitioning = $Partition_Parameter], [FST = ".($NDE_Parameter==0?"Disable":"Enable")."], [Breaking Symmetry = $BS_Parameter]\n";
	print "a	                        [DBMode = $XOL_Mode($XOL_Parameter)], [Objective Partitioning = $objpart_Parameter]\n\n";
    print "a   Generating SMT-LIB 2.0 Standard inputfile based on the following files.\n";
    print "a     Input Layout:  $workdir/$infile\n";
}

### Output Directory Creation, please see the following reference:
system "mkdir -p $outdir";

my $outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0].".smt2";
print "a     SMT-LIB2.0 File:    $outfile\n";

### Variable Declarations
my $width = 0;
my $placementRow = 0;
my $trackEachRow = 0;
my $trackEachPRow = 0;
my $numTrackH = 0;
my $numTrackV = 0;
my $numMetalLayer = $MM_Parameter;      # M1~M4
my $numPTrackH = 0;
my $numPTrackV = 0;

### PIN variables
my @pins = ();
my @pin = ();
my $pinName = "";
my $pin_netID = ""; 
my $pin_instID = "";			
my $pin_type = "";		
my $pin_type_IO = "";		
my $pinIO = "";
my $pinXpos = -1;
my @pinYpos = ();
my $pinLength = -1;
my $pinStart = -1;
my $totalPins = -1;
my $pinIDX = 0;
my $pinTotalIDX = 0;
my %h_pin_id = ();
my %h_pin_idx = ();
my %h_pinId_idx = ();
my %h_outpinId_idx = ();
my %h_pin_net = ();

### NET variables
my @nets = ();
my @net = ();
my $netName = "";
my $netID = -1;
my $N_pinNets = 0;
my $numSinks = -1;
my $source_ofNet = "";
my @pins_inNet = ();
my @sinks_inNet = ();
my $totalNets = -1;
my $idx_nets = 0;
my $numNets_org = 0;
my %h_extnets = ();
my %h_idx = ();
my %h_outnets = ();
my %h_pwrnets = ();

### Instance variables
my $numInstance = 0;
my $instName = "";
my $instType = "";
my $instWidth = 0;
my $instGroup = 0;
my $instY = 0;
my @inst = ();
my $lastIdxPMOS = -1;
my %h_inst_idx = ();
my @numFinger = ();
my $minWidth = 0;
my $numPowerPmos = 0;
my $numPowerNmos = 0;
my @inst_group = ();
my %h_inst_group = ();
my @inst_group_p = ();
my @inst_group_n = ();
my %h_sdbcell = ();

### Power Net/Pin Info
my %h_pin_power = ();
my %h_net_power = ();
my %h_net_track = ();

sub combine;
sub combine_sub;
sub getAvailableNumFinger{
	$width = @_[0];
	$trackEachPRow = @_[1];

	@numFinger = ();
	for my $i(0 .. $trackEachPRow-1){
		if($width % ($trackEachPRow-$i) == 0){
			push(@numFinger, $width/($trackEachPRow-$i));
			last;
		}
	}
	return @numFinger;
}
sub combine {
	my ($list, $n) = @_;
	die "Insufficient list members" if $n > @$list;

	return map [$_], @$list if $n <= 1;

	my @comb;

	for (my $i = 0; $i+$n <= @$list; ++$i){
		my $val = $list->[$i];
		my @rest = @$list[$i+1..$#$list];
		push @comb, [$val, @$_] for combine_sub \@rest, $n-1;
		if($i==0){
			last;
		}
	}

	return @comb;
}
sub combine_sub {
	my ($list, $n) = @_;
	die "Insufficient list members" if $n > @$list;

	return map [$_], @$list if $n <= 1;

	my @comb;

	for (my $i = 0; $i+$n <= @$list; ++$i){
		my $val = $list->[$i];
		my @rest = @$list[$i+1..$#$list];
		push @comb, [$val, @$_] for combine_sub \@rest, $n-1;
	}

	return @comb;
}
my $infileStatus = "init";

### Read Inputfile and Build Data Structure
open (my $in, "./$infile");
while (<$in>) {
    my $line = $_;
    chomp($line);

    ### Status of Input File
    if ($line =~ /===InstanceInfo===/) {
        $infileStatus = "inst";
    } 
    elsif ($line =~ /===NetInfo===/) {
        $infileStatus = "net";
		for(my $i=0; $i<=$#pins; $i++){
			if(exists($h_pin_net{$pins[$i][1]})){
				if($pins[$i][2] eq "s"){
					$h_pin_net{$pins[$i][1]} = $h_pin_net{$pins[$i][1]}." ".$pins[$i][0];
				}
				else{
					$h_pin_net{$pins[$i][1]} = $pins[$i][0]." ".$h_pin_net{$pins[$i][1]};
				}
			}
			else{
				$h_pin_net{$pins[$i][1]} = $pins[$i][0];
			}
		}
    }
    elsif ($line =~ /===PinInfo===/) {
        $infileStatus = "pin";
    }
    elsif ($line =~ /===PartitionInfo===/) {
        $infileStatus = "partition";
    }
    elsif ($line =~ /===SpecialNetInfo===/) {
        $infileStatus = "specialnet";
    }
    elsif ($line =~ /===SDBCellInfo===/) {
        $infileStatus = "sdbcell";
    }

    ### Infile Status: init
    if ($infileStatus eq "init") {
        if ($line =~ /Width of Routing Clip\s*= (\d+)/) {
            $width = $1;
            $numTrackV = $width;
            print "a     # Vertical Tracks   = $numTrackV\n";
        }
        elsif ($line =~ /Height of Routing Clip\s*= (\d+)/) {
            $placementRow = $1;
        }
        elsif ($line =~ /Tracks per Placement Row\s*= (\d+)/) {
            $trackEachRow = $1;
            $numTrackH = $placementRow * $trackEachRow;
            print "a     # Horizontal Tracks = $numTrackH\n";
        }
        elsif ($line =~ /Width of Placement Clip\s*= (\d+)/) {
            $width = $1;
            $numPTrackV = $width;
            print "a     # Vertical Placement Tracks   = $numPTrackV\n";
        }
        elsif ($line =~ /Tracks per Placement Clip\s*= (\d+)/) {
            $numPTrackH = $1*2;
			$trackEachPRow = $1;
            print "a     # Horizontal Placement Tracks = $numPTrackH\n";
        }
    }

    ### Infile Status: Instance Info
    if ($infileStatus eq "inst") {
        if ($line =~ /^i   ins(\S+)\s*(\S+)\s*(\d+)/) {	
			$instName = "ins".$1;
			$instType = $2;
			$instWidth = $3;

			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($instWidth, $trackEachPRow);

			if($instType eq "NMOS"){
				if($lastIdxPMOS == -1){
					$lastIdxPMOS = $numInstance - 1;
				}
				$instY = 0;
			}
			else{
				$instY = $numPTrackH - $instWidth/$tmp_finger[0];
			}
			push(@inst, [($instName, $instType, $instWidth, $instY)]);
			### Generate Maximum possible pin arrays for each instances
			### # of Maximum Possible pin = instWidth * 2 + 1
			for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
				if($i==0){
					$h_pin_idx{$instName} = $pinIDX;
				}
				@pinYpos = ();
				for my $pinRow (1 .. $trackEachPRow) {
					push (@pinYpos, $pinRow );
				}
				@pin = ("pin$1_$i", "", "t", $trackEachPRow, $i, [@pinYpos], $instName, "");
				push (@pins, [@pin]);
				$h_pinId_idx{"pin$1_$i"} = $pinIDX;
				$pinIDX++;
				$pinTotalIDX++;
			}
			$h_inst_idx{$instName} = $numInstance;
			$numInstance++;
		}
    }

    ### Infile Status: pin
    if ($infileStatus eq "pin") {
		if ($line =~ /^i   pin(\d+)\s*net(\d+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)/) {
			$pin_type_IO = $7;
		}
		if ($line =~ /^i   pin(\d+)\s*net(\d+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)/) {
            $pinName = "pin".$1;
            $pin_netID = "net".$2; 
			$pin_instID = $3;
			$pin_type = $4;
            $pinIO = $5;
            $pinLength = $6;
			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($inst[$h_inst_idx{$pin_instID}][2], $trackEachPRow);
			if($pin_instID ne "ext" && $pin_type eq "S"){
				for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
					if($i%4==0){
						$pins[$h_pin_idx{$pin_instID}+$i][1] = $pin_netID;
						$pins[$h_pin_idx{$pin_instID}+$i][7] = $pin_type;
						if($i==0){
							$pins[$h_pin_idx{$pin_instID}+$i][2] = $pinIO;
						}
					}
				}
			}
			elsif($pin_instID ne "ext" && $pin_type eq "D"){
				for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
					if($i>=2 && ($i-2)%4==0){
						$pins[$h_pin_idx{$pin_instID}+$i][1] = $pin_netID;
						$pins[$h_pin_idx{$pin_instID}+$i][7] = $pin_type;
						if($i==2){
							$pins[$h_pin_idx{$pin_instID}+$i][2] = $pinIO;
						}
					}
				}
			}
			elsif($pin_instID ne "ext" && $pin_type eq "G"){
				for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
					if($i>=1 && ($i)%2==1){
						$pins[$h_pin_idx{$pin_instID}+$i][1] = $pin_netID;
						$pins[$h_pin_idx{$pin_instID}+$i][7] = $pin_type;
						if($i==1){
							$pins[$h_pin_idx{$pin_instID}+$i][2] = $pinIO;
						}
					}
				}
			}
			elsif($pin_instID eq "ext"){
				@pin = ($pinName, $pin_netID, $pinIO, $pinLength, $pinXpos, [@pinYpos], $pin_instID, $pin_type);
				push (@pins, [@pin]);
				$h_outpinId_idx{$pinName} = $pinTotalIDX;
				$pinTotalIDX++;
				if($pin_type ne "VDD" && $pin_type ne "VSS"){
					$h_extnets{$2} = 1;
				}
				else{
					$h_pwrnets{$2} = 1;
				}
				if($pin_type_IO eq "O"){
					$h_outnets{$pin_netID} = 1;
				}
			} 
			$h_pin_id{$pin_instID."_".$pin_type} = $2;
        }
    }

    ### Infile Status: net
    if ($infileStatus eq "net") {
        if ($line =~ /^i   net(\S+)\s*(\d+)PinNet/) {
			$numNets_org++;
            $netID = $1;
            $netName = "net".$netID;
			my $powerinNet = 0;
			my $powerNet = "";
			if(exists($h_pin_net{$netName})){
				@net = split /\s+/, $h_pin_net{$netName};
			}
			else{
				print "[ERROR] Parsing Net Info : Net Information is not correct!! [$netName]\n";
				exit(-1);
			}
            for my $pinIndex_inNet (0 .. $#net) {
				if(exists($h_outpinId_idx{$net[$pinIndex_inNet]}) && ($pins[$h_outpinId_idx{$net[$pinIndex_inNet]}][7] eq "VDD" || $pins[$h_outpinId_idx{$net[$pinIndex_inNet]}][7] eq "VSS")){
					$powerinNet = 1;
					$powerNet = $net[$pinIndex_inNet];
				}
			}
			if($powerinNet == 0){
				$N_pinNets = $#net+1;
				@pins_inNet = ();
				my $num_outpin = 0;
				for my $pinIndex_inNet (0 .. $N_pinNets-1) {
					push (@pins_inNet, $net[$pinIndex_inNet]);
				}
				$source_ofNet = $pins_inNet[$N_pinNets-1];
				$numSinks = $N_pinNets - 1;
				@sinks_inNet = ();
				for my $sinkIndex_inNet (0 .. $numSinks-1) {
					push (@sinks_inNet, $net[$sinkIndex_inNet]);
				}
				$numSinks = $numSinks - $num_outpin;
				@net = ($netName, $netID, $N_pinNets, $source_ofNet, $numSinks, [@sinks_inNet], [@pins_inNet]);
				push (@nets, [@net]);
				$idx_nets++;
			}
			else{
				my $subidx_net = 0;
				
				for my $pinIndex_inNet (0 .. $#net) {
					$h_pin_power{$net[$pinIndex_inNet]} = 1;
					$N_pinNets = 2;
					@pins_inNet = ();
					@sinks_inNet = ();
					if($net[$pinIndex_inNet] ne $powerNet){
						push (@pins_inNet, $powerNet);
						push (@pins_inNet, $net[$pinIndex_inNet]);
						$source_ofNet = $net[$pinIndex_inNet];
						$numSinks = 1;
						push (@sinks_inNet, $powerNet);
						my @tmpnet = ($netName."_".$subidx_net, $netID."_".$subidx_net, $N_pinNets, $source_ofNet, $numSinks, [@sinks_inNet], [@pins_inNet]);
						push (@nets, [@tmpnet]);
						$h_net_power{$netName."_".$subidx_net} = 1;
						$pins[$h_outpinId_idx{$powerNet}][1] = $netName."_".$subidx_net;
						$pins[$h_pinId_idx{$source_ofNet}][1] = $netName."_".$subidx_net;
						$pins[$h_pinId_idx{$source_ofNet}][2] = "s";
						$idx_nets++;
						$subidx_net++;
						## Generate Instance Information for applying DDA
						if($pins[$h_pinId_idx{$source_ofNet}][7] eq "S"){
							my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$source_ofNet}][6]};
							my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);
							my $FlipFlag = 0;
							if($tmp_finger[0]%2 == 0){
								$FlipFlag = 2;
							}
						}
						elsif($pins[$h_pinId_idx{$source_ofNet}][7] eq "D"){
							my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$source_ofNet}][6]};
							my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);
							my $FlipFlag = 0;
							if($tmp_finger[0]%2 == 1){
								$FlipFlag = 1;
							}
							else{
								next;
							}
						}
					}
				}
			}
        }
    }
    ### Infile Status: Partition Info
    if ($Partition_Parameter == 1 && $infileStatus eq "partition") {
        if ($line =~ /^i   ins(\S+)\s*(\S+)\s*(\d+)/) {	
			$instName = "ins".$1;
			$instType = $2;
			$instGroup = $3;

			if(!exists($h_inst_idx{$instName})){
				print "[ERROR] Instance [$instName] in PartitionInfo not found!!\n";
				exit(-1);
			}
			my $idx = $h_inst_idx{$instName};

			print "a     [Cell Partitioning] $instName => Group $instGroup\n";

			push(@inst_group, [($instName, $instType, $instGroup)]);
			$h_inst_group{$idx} = $instGroup;
		}
    }
    ### Infile Status: Special Net Info
    if ($infileStatus eq "specialnet") {
        if ($line =~ /^i\s*\t*net(\d+)/) {	
			my $net_idx = $1;

			print "a     [Crosstalk Mitigation Net Assign] net$net_idx\n";
			$h_net_track{"$net_idx"} = 1;
		}
    }
    ### Infile Status: SDB Possible Sell Info
    if ($infileStatus eq "sdbcell") {
        if ($line =~ /^i   ins(\S+)\s*(\S+)/) {	
			$instName = "ins".$1;
			$instType = $2;
			my $idx = $h_inst_idx{$instName};

			print "a     [SDB in Crossover] $instName($instType)\n";
			$h_sdbcell{$idx} = $instName;
		}
    }
}
close ($in);

# Generating Instance Group Array
if ($Partition_Parameter == 1){
	my @inst_sorted = ();
	@inst_sorted = sort { (($a->[2] =~ /(\d+)/)[0]||0) <=> (($b->[2] =~ /(\d+)/)[0]||0) || $a->[2] cmp $b->[2] } @inst_group;

	my $prev_group_p = -1;
	my $prev_group_n = -1;
	my @arr_tmp_p = ();
	my @arr_tmp_n = ();
	my $minWidth_p = 0;
	my $minWidth_n = 0;
	my $isRemain_P = 0;
	my $isRemain_N = 0;
	for my $i(0 .. $#inst_sorted){
		if($h_inst_idx{$inst_sorted[$i][0]} <= $lastIdxPMOS){
			if($prev_group_p != -1 && $prev_group_p != $inst_sorted[$i][2]){
				push(@inst_group_p, [($prev_group_p, [@arr_tmp_p], $minWidth_p)]);
				@arr_tmp_p = ();
				$minWidth_p = 0;
			}
			push(@arr_tmp_p, $h_inst_idx{$inst_sorted[$i][0]});
			$prev_group_p = $inst_sorted[$i][2];
			$isRemain_P = 1;
			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($inst[$h_inst_idx{$inst_sorted[$i][0]}][2], $trackEachPRow);
			$minWidth_p+=2*$tmp_finger[0];
		}
		else{
			if($prev_group_n != -1 && $prev_group_n != $inst_sorted[$i][2]){
				push(@inst_group_n, [($prev_group_n, [@arr_tmp_n], $minWidth_n)]);
				@arr_tmp_n = ();
				$minWidth_n = 0;
			}
			push(@arr_tmp_n, $h_inst_idx{$inst_sorted[$i][0]});
			$prev_group_n = $inst_sorted[$i][2];
			$isRemain_N = 1;
			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($inst[$h_inst_idx{$inst_sorted[$i][0]}][2], $trackEachPRow);
			$minWidth_n+=2*$tmp_finger[0];
		}
	}
	if($isRemain_P == 1){
		push(@inst_group_p, [($prev_group_p, [@arr_tmp_p], $minWidth_p)]);
	}
	if($isRemain_N == 1){
		push(@inst_group_n, [($prev_group_n, [@arr_tmp_n], $minWidth_n)]);
	}
}

### Remove Power Pin/Net Information from data structure 
my @tmp_pins = ();
my @tmp_nets = ();
my @nets_sorted = ();

$pinIDX = 0;
for my $i (0 .. (scalar @pins)-1){
	if(!exists($h_pin_power{$pins[$i][0]})){
		push(@tmp_pins, $pins[$i]);
		$h_pinId_idx{$pins[$i][0]} = $pinIDX;
		if($pins[$i][7] ne "S" && $pins[$i][7] ne "D" && $pins[$i][7] ne "G"){
			$h_outpinId_idx{$pins[$i][0]} = $pinIDX;
		}
		$pinIDX++;
	}
}
my $tmp_net_idx = 0;
for my $i (0 .. (scalar @nets)-1){
	if(!exists($h_net_power{$nets[$i][0]})){
		push(@tmp_nets, $nets[$i]);
		$h_idx{$nets[$i][1]} = $tmp_net_idx;
		$tmp_net_idx++;
	}
}
@pins = @tmp_pins;
@nets = @tmp_nets;

@nets_sorted = sort { (($b->[2] =~ /(\d+)/)[0]||0) <=> (($a->[2] =~ /(\d+)/)[0]||0) || $b->[2] cmp $a->[2] } @nets;

$totalPins = scalar @pins;
$totalNets = scalar @nets;
print "a     # Pins              = $totalPins\n";
print "a     # Nets              = $totalNets\n";

### VERTEX Generation
### VERTEX Variables
my %vertices = ();
my @vertex = ();
my $numVertices = -1;
my $vIndex = 0;
my $vName = "";
my @vADJ = ();
my $vL = "";
my $vR = "";
my $vF = "";
my $vB = "";
my $vU = "";
my $vD = "";
my $vFL = "";
my $vFR = "";
my $vBL = "";
my $vBR = "";

### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
for my $metal (1 .. $numMetalLayer) { 
    for my $row (0 .. $numTrackH-3) {
        for my $col (0 .. $numTrackV-1) {
            $vName = "m".$metal."r".$row."c".$col;
			if ($col == 0) { ### Left Vertex
				$vL = "null";
			} 
			else {
				$vL = "m".$metal."r".$row."c".($col-1);
			}
			if ($col == $numTrackV-1) { ### Right Vertex
				$vR = "null";
			}
			else {
				$vR = "m".$metal."r".$row."c".($col+1);
			}
			if ($row == 0) { ### Front Vertex
				$vF = "null";
			}
			else {
				$vF = "m".$metal."r".($row-1)."c".$col;
			}
			if ($row == $numTrackH-3) { ### Back Vertex
				$vB = "null";
			}
			else {
				$vB = "m".$metal."r".($row+1)."c".$col;
			}
			if ($metal == $numMetalLayer) { ### Up Vertex
				$vU = "null";
			}
			else {
				$vU = "m".($metal+1)."r".$row."c".$col;
			}
			if ($metal == 1) { ### Down Vertex
				$vD = "null";
			}
			else {
				$vD = "m".($metal-1)."r".$row."c".$col;
			}
			if ($row == 0 || $col == 0) { ### FL Vertex
				$vFL = "null";
			}
			else {
				$vFL = "m".$metal."r".($row-1)."c".($col-1);
			}
			if ($row == 0 || $col == $numTrackV-1) { ### FR Vertex
				$vFR = "null";
			}
			else {
				$vFR = "m".$metal."r".($row-1)."c".($col+1);
			}
			if ($row == $numTrackH-3 || $col == 0) { ### BL Vertex
				$vBL = "null";
			}
			else {
				$vBL = "m".$metal."r".($row+1)."c".($col-1);
			}
			if ($row == $numTrackH-3 || $col == $numTrackV-1) { ### BR Vertex
				$vBR = "null";
			}
			else {
				$vBR = "m".$metal."r".($row+1)."c".($col+1);
			}
            @vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
            @vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
            $vertices{$vName} = [@vertex];
            $vIndex++;
        }
    }
}
$numVertices = keys %vertices;
print "a     # Vertices          = $numVertices\n";

### UNDIRECTED EDGE Generation
### UNDIRECTED EDGE Variables
my @udEdges = ();
my @udEdge = ();
my $udEdgeTerm1 = "";
my $udEdgeTerm2 = "";
my $udEdgeIndex = 0;
my $udEdgeNumber = -1;
my $vCost = 4;
my $mCost = 1;
my $vCost_1 = 4;
my $mCost_1 = 1;
my $vCost_34 = 4;
my $mCost_4 = 1;
my $wCost = 1;

### DATA STRUCTURE:  UNDIRECTED_EDGE [index] [Term1] [Term2] [mCost] [wCost]
for my $metal (1 .. $numMetalLayer) {     # Odd Layers: Vertical Direction   Even Layers: Horizontal Direction
    for my $row (0 .. $numTrackH-3) {
        for my $col (0 .. $numTrackV-1) {
            $udEdgeTerm1 = "m".$metal."r".$row."c".$col;
            if ($metal % 2 == 0) { # Even Layers ==> Horizontal
                if ($vertices{$udEdgeTerm1}[5][1] ne "null") { # Right Edge
                    $udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][1];
					if($metal == 4){
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost_4, $wCost);
					}
					else{
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost, $wCost);
					}
                    #print "@udEdge\n";
                    push (@udEdges, [@udEdge]);
                    $udEdgeIndex++;
                }
                if ($vertices{$udEdgeTerm1}[5][4] ne "null") { # Up Edge
					if($col % 2 == 0){
						$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][4];
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost, $vCost);
						#print "@udEdge\n";
						push (@udEdges, [@udEdge]);
						$udEdgeIndex++;
					}
                }
            }
            else { # Odd Layers ==> Vertical
				if($metal > 1 && $col %2 == 1){
					next;
				}
                if ($vertices{$udEdgeTerm1}[5][3] ne "null") { # Back Edge
                    $udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][3];
					if($metal == 3){
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost, $wCost);
					}
					else{
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost_1, $wCost);
					}
                    #print "@udEdge\n";
                    push (@udEdges, [@udEdge]);
                    $udEdgeIndex++;
                }
                if ($vertices{$udEdgeTerm1}[5][4] ne "null") { # Up Edge
					if($metal == 1){
						$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][4];
						if($metal == 3){
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_34, $vCost);
						}
						else{
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_1, $vCost);
						}
						#print "@udEdge\n";
						push (@udEdges, [@udEdge]);
						$udEdgeIndex++;
					}
					elsif($col % 2 == 0){
						$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][4];
						if($metal == 3){
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_34, $vCost);
						}
						else{
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_1, $vCost);
						}
						#print "@udEdge\n";
						push (@udEdges, [@udEdge]);
						$udEdgeIndex++;
					}
                }
            }
        }
    }
}
$udEdgeNumber = scalar @udEdges;
print "a     # udEdges           = $udEdgeNumber\n";

### BOUNDARY VERTICES Generation.
### DATA STRUCTURE:  Single Array includes all boundary vertices to L, R, F, B, U directions.
my @boundaryVertices = ();
my $numBoundaries = 0;

### Normal External Pins - Top&top-1 layer only
for my $metal ($numMetalLayer-1 .. $numMetalLayer) { 
    for my $row (0 .. $numTrackH-3) {
        for my $col (0 .. $numTrackV-1) {
			if($metal%2==0){
				if($col%2 == 1){
					next;
				}
			}
			else{
				if($col%2 == 1){
					next;
				}
				if($EXT_Parameter == 0){
					if ($row == 1 || $row == $numTrackH-4) {
						push (@boundaryVertices, "m".$metal."r".$row."c".$col);
					}
				}
				else{
					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
				}
			}
        }
    }
}

$numBoundaries = scalar @boundaryVertices;
print "a     # Boundary Vertices = $numBoundaries\n";

my @outerPins = ();
my @outerPin = ();
my %h_outerPin = ();
my $numOuterPins = 0;
my $commodityInfo = -1;

for my $pinID (0 .. $#pins) {
    if ($pins[$pinID][3] == -1) {
        $commodityInfo = -1;  # Initializing
        # Find Commodity Infomation
        for my $netIndex (0 .. $#nets) {
            if ($nets[$netIndex][0] eq $pins[$pinID][1]){
                for my $sinkIndexofNet (0 .. $nets[$netIndex][4]){
                    if ( $nets[$netIndex][5][$sinkIndexofNet] eq $pins[$pinID][0]){
                        $commodityInfo = $sinkIndexofNet; 
                    }    
                }
            }
        }
        if ($commodityInfo == -1){
            print "ERROR: Cannot Find the commodity Information!!\n\n";
        }
        @outerPin = ($pins[$pinID][0],$pins[$pinID][1],$commodityInfo);
        push (@outerPins, [@outerPin]) ;
		$h_outerPin{$pins[$pinID][0]} = 1;
    }
}
$numOuterPins = scalar @outerPins;

### (LEFT | RIGHT | FRONT | BACK) CORNER VERTICES Generation
my @leftCorners = ();
my $numLeftCorners = 0;
my @rightCorners = ();
my $numRightCorners = 0;
my @frontCorners = ();
my $numFrontCorners = 0;
my @backCorners = ();
my $numBackCorners = 0;
my $cornerVertex = "";

for my $metal (1 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
    for my $row (0 .. $numTrackH-3) {
        for my $col (0 .. $numTrackV-1) {
			if($metal==1 && $col % 2 == 1){
				next;
			}
			elsif($metal % 2 == 1 && $col % 2 == 1){
				next;
			}
            $cornerVertex = "m".$metal."r".$row."c".$col;
            if ($col == 0) {
                push (@leftCorners, $cornerVertex);
                $numLeftCorners++;
            }
            if ($col == $numTrackV-1) {
                push (@rightCorners, $cornerVertex);
                $numRightCorners++;
            }
            if ($row == 0) {
                push (@frontCorners, $cornerVertex);
                $numFrontCorners++;
            }
            if ($row == $numTrackH-3) {
                push (@backCorners, $cornerVertex);
                $numBackCorners++;
            }
        }
    }
}
#print "@backCorners\n";
print "a     # Left Corners      = $numLeftCorners\n";
print "a     # Right Corners     = $numRightCorners\n";
print "a     # Front Corners     = $numFrontCorners\n";
print "a     # Back Corners      = $numBackCorners\n";

### SOURCE and SINK Generation.  All sources and sinks are supernodes.
### DATA STRUCTURE:  SOURCE or SINK [netName] [#subNodes] [Arr. of sub-nodes, i.e., vertices]
my %sources = ();
my %sinks = ();
my @source = ();
my @sink = ();
my @subNodes = ();
my $numSubNodes = 0;
my $numSources = 0;
my $numSinks = 0;

my $outerPinFlagSource = 0;
my $outerPinFlagSink = 0;
my $keyValue = "";

# Super Outer Node Keyword
my $keySON = "pinSON";

for my $pinID (0 .. $#pins) {
    @subNodes = ();
    if ($pins[$pinID][2] eq "s") { # source
        if ($pins[$pinID][3] == -1) {
            if ($SON == 1){
                if ($outerPinFlagSource == 0){
                    @subNodes = @boundaryVertices;
                    $outerPinFlagSource = 1;
                    $keyValue = $keySON;
                }
                else{
                    next;
                }
            }
            else{   # SON Disable
                @subNodes = @boundaryVertices;
                $keyValue = $pins[$pinID][0];
            }
        } else {
            for my $node (0 .. $pins[$pinID][3]-1) {
                push (@subNodes, "m1r".$pins[$pinID][5][$node]."c".$pins[$pinID][4]);
            }
            $keyValue = $pins[$pinID][0];
        }
        $numSubNodes = scalar @subNodes;
        @source = ($pins[$pinID][1], $numSubNodes, [@subNodes]);
        # Outer Pin should be at last in the input File Format [2018-10-15]
        $sources{$keyValue} = [@source];
    }
    elsif ($pins[$pinID][2] eq "t") { # sink
        if ($pins[$pinID][3] == -1) {
            if ( $SON == 1) {        
				if ($outerPinFlagSink == 0){
					@subNodes = @boundaryVertices;
					$outerPinFlagSink = 1;
					$keyValue = $keySON;
				}
				else{
					next;
				}
            }
            else{ 
                @subNodes = @boundaryVertices;
                $keyValue = $pins[$pinID][0];
            }
        } else {
            for my $node (0 .. $pins[$pinID][3]-1) {
                push (@subNodes, "m1r".$pins[$pinID][5][$node]."c".$pins[$pinID][4]);
            }
            $keyValue = $pins[$pinID][0];
        }
        $numSubNodes = scalar @subNodes;
        @sink = ($pins[$pinID][1], $numSubNodes, [@subNodes]);
        $sinks{$keyValue} = [@sink];
    }
}
my $numExtNets = keys %h_extnets;
$numSources = keys %sources;
$numSinks = keys %sinks;
print "a     # Ext Nets          = $numExtNets\n";
print "a     # Sources           = $numSources\n";
print "a     # Sinks             = $numSinks\n";

if ( $SON == 1){
############### Pin Information Modification #####################
    for my $pinIndex (0 .. $#pins) {
        for my $outerPinIndex (0 .. $#outerPins){
            if ($pins[$pinIndex][0] eq $outerPins[$outerPinIndex][0] ){
				$pins[$pinIndex][0] = $keySON;
				$pins[$pinIndex][1] = "Multi";
				next;
            }   
        }
    }
############ SON Node should be last elements to use pop ###########
    my $SONFlag = 0;
	my $tmp_cnt = $#pins;
	for(my $i=0; $i<=$tmp_cnt; $i++){
		if($pins[$tmp_cnt-$i][0] eq $keySON){
			$SONFlag = 1;
			@pin = pop @pins;
		}
	}
    if ($SONFlag == 1){
        push (@pins, @pin);
    }
}
############### Net Information Modification from Outer pin to "SON"
if ( $SON == 1 ){
    for my $netIndex (0 .. $#nets) {
        for my $sinkIndex (0 .. $nets[$netIndex][4]-1){
            for my $outerPinIndex (0 .. $#outerPins){
                if ($nets[$netIndex][5][$sinkIndex] eq $outerPins[$outerPinIndex][0] ){
					$nets[$netIndex][5][$sinkIndex] = $keySON;
                    next;
                }
            }
        }
        for my $pinIndex (0 .. $nets[$netIndex][2]-1){
            for my $outerPinIndex (0 .. $#outerPins){
                if ($nets[$netIndex][6][$pinIndex] eq $outerPins[$outerPinIndex][0] ){
					$nets[$netIndex][6][$pinIndex] = $keySON;
                    next;
                }
            }
        }
    }
}

### VIRTUAL EDGE Generation
### We only define directed virtual edges since we know the direction based on source/sink information.
### All supernodes are having names starting with 'pin'.
### DATA STRUCTURE:  VIRTUAL_EDGE [index] [Origin] [Destination] [Cost=0]
my @virtualEdges = ();
my @virtualEdge = ();
my $vEdgeIndex = 0;
my $vEdgeNumber = 0;
my $virtualCost = 0;

for my $pinID (0 .. $#pins) {
    if ($pins[$pinID][2] eq "s") { # source
        if(exists $sources{$pins[$pinID][0]}){
			if(exists($h_inst_idx{$pins[$pinID][6]})){
				my $instIdx = $h_inst_idx{$pins[$pinID][6]};
				my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);

				if($h_inst_idx{$pins[$pinID][6]} <= $lastIdxPMOS){
					my $ru = $h_RTrack{$numPTrackH-1-$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
					my $rl = $h_RTrack{$numPTrackH-1};

					for my $row (0 .. $numTrackH/2-2){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
				}
				else
				{
					my $ru = $h_RTrack{0};
					my $rl = $h_RTrack{$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};

					for my $row ($numTrackH/2-1 .. $numTrackH-3){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
				}
			}
			else{
				print "[ERROR] Virtual Edge Generation : Instance Information not found!!\n";
				exit(-1);
			}
        }
    }
    elsif ($pins[$pinID][2] eq "t") { # sink
        if(exists $sinks{$pins[$pinID][0]}){
			if($pins[$pinID][0] eq $keySON){
			   for my $term (0 ..  $sinks{$pins[$pinID][0]}[1]-1){
					@virtualEdge = ($vEdgeIndex, $sinks{$pins[$pinID][0]}[2][$term], $pins[$pinID][0], $virtualCost);
					push (@virtualEdges, [@virtualEdge]);
					$vEdgeIndex++;
				}
			}
			elsif(exists($h_inst_idx{$pins[$pinID][6]})){
				my $instIdx = $h_inst_idx{$pins[$pinID][6]};
				my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);

				if($h_inst_idx{$pins[$pinID][6]} <= $lastIdxPMOS){
					my $ru = $h_RTrack{$numPTrackH-1-$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
					my $rl = $h_RTrack{$numPTrackH-1};

					for my $row (0 .. $numTrackH/2-2){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
				}
				else{
					my $ru = $h_RTrack{0};
					my $rl = $h_RTrack{$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};

					for my $row ($numTrackH/2-1 .. $numTrackH-3){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
				}
			}
			else{
				print "[ERROR] Virtual Edge Generation : Instance Information not found!!\n";
				exit(-1);
			}
        }
    }
}
my %edge_in = ();
my %edge_out = ();
for my $edge (0 .. @udEdges-1){
	push @{ $edge_out{$udEdges[$edge][1]} }, $edge;
	push @{ $edge_in{$udEdges[$edge][2]} }, $edge;
}
my %vedge_in = ();
my %vedge_out = ();
for my $edge (0 .. @virtualEdges-1){
	push @{ $vedge_out{$virtualEdges[$edge][1]} }, $edge;
	push @{ $vedge_in{$virtualEdges[$edge][2]} }, $edge;
}

## Variable, Constraints Number Count
my $c_v_placement = 0;
my $c_v_placement_aux = 0;
my $c_v_routing = 0;
my $c_v_routing_aux = 0;
my $c_v_connect = 0;
my $c_v_connect_aux = 0;
my $c_v_dr = 0;
my $c_c_placement = 0;
my $c_c_routing = 0;
my $c_c_connect = 0;
my $c_c_dr = 0;
my $c_l_placement = 0;
my $c_l_routing = 0;
my $c_l_connect = 0;
my $c_l_dr = 0;

my $type = "";
my $idx = 0;
sub cnt{
	$type = @_[0];
	$idx = @_[1];

	## Variable
	if($type eq "v"){
		if($idx == 0){
			$c_v_placement++;
		}
		elsif($idx == 1){
			$c_v_placement_aux++;
		}
		elsif($idx == 2){
			$c_v_routing++;
		}
		elsif($idx == 3){
			$c_v_routing_aux++;
		}
		elsif($idx == 4){
			$c_v_connect++;
		}
		elsif($idx == 5){
			$c_v_connect_aux++;
		}
		elsif($idx == 6){
			$c_v_dr++;
		}
		else{
			print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
			exit(-1);
		}
	}
	## Constraints
	elsif($type eq "c"){
		if($idx == 0){
			$c_c_placement++;
		}
		elsif($idx == 1){
			$c_c_routing++;
		}
		elsif($idx == 2){
			$c_c_connect++;
		}
		elsif($idx == 3){
			$c_c_dr++;
		}
		else{
			print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
			exit(-1);
		}
	}
	## Literals
	elsif($type eq "l"){
		if($idx == 0){
			$c_l_placement++;
		}
		elsif($idx == 1){
			$c_l_routing++;
		}
		elsif($idx == 2){
			$c_l_connect++;
		}
		elsif($idx == 3){
			$c_l_dr++;
		}
		else{
			print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
			exit(-1);
		}
	}
	else{
		print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
		exit(-1);
	}
	return;
}

$vEdgeNumber = scalar @virtualEdges;
print "a     # Virtual Edges     = $vEdgeNumber\n";

### END:  DATA STRUCTURE ##############################################################################################

open (my $out, '>', $outfile);
print "a   Generating SMT-LIB 2.0 Standard Input Code.\n";

### INIT
print $out ";Formulation for SMT\n";
print $out ";	Format: SMT-LIB 2.0\n";
print $out ";	Version: 1.0\n";
print $out ";   Authors:     Daeyeal Lee, Dongwon Park, Chung-Kuan Cheng\n";
print $out ";   DO NOT DISTRIBUTE IN ANY PURPOSE! \n\n";
print $out ";	Input File:  $workdir/$infile\n";
print $out ";   Design Rule Parameters : [MAR = $MAR_Parameter , EOL = $EOL_Parameter, VR = $VR_Parameter, PRL = $PRL_Parameter, SHR = $SHR_Parameter]\n";
print $out ";   Parameter Options : [MPO = $MPL_Parameter], [Localization = $Local_Parameter (T$tolerance)]\n";
print $out ";                       [Cell Partitioning = $Partition_Parameter], [FST = ".($NDE_Parameter==0?"Disable":"Enable")."], [Breaking Symmetry = $BS_Parameter]\n";
print $out ";                       [DBMode = $XOL_Mode($XOL_Parameter)], [Objective Partitioning = $objpart_Parameter]\n\n";

print $out ";Layout Information\n";
print $out ";	Placement\n";
print $out ";	# Vertical Tracks   = $numPTrackV\n";
print $out ";	# Horizontal Tracks = $numPTrackH\n";
print $out ";	# Instances         = $numInstance\n";
print $out ";	Routing\n";
print $out ";	# Vertical Tracks   = $numTrackV\n";
print $out ";	# Horizontal Tracks = $numTrackH\n";
print $out ";	# Nets              = $totalNets\n";
print $out ";	# Pins              = $totalPins\n";
print $out ";	# Sources           = $numSources\n";
print $out ";	List of Sources   = ";
foreach my $key (sort(keys %sources)) {
    print $out "$key ";
}
print $out "\n";
print $out ";	# Sinks             = $numSinks\n";
print $out ";	List of Sinks     = ";
foreach my $key (sort(keys %sinks)) {
    print $out "$key ";
}
print $out "\n";
print $out ";	# Outer Pins        = $numOuterPins\n";
print $out ";	List of Outer Pins= ";
for my $i (0 .. $#outerPins) {              # All SON (Super Outer Node)
    print $out "$outerPins[$i][0] ";        # 0 : Pin number , 1 : net number
}
print $out "\n";
print $out ";	Outer Pins Information= ";
for my $i (0 .. $#outerPins) {              # All SON (Super Outer Node)
    print $out " $outerPins[$i][1]=$outerPins[$i][2] ";        # 0 : Net number , 1 : Commodity number
}
print $out "\n";
print $out "\n\n";

my $str = "";
my %h_var = ();
my $idx_var = 1;
my $idx_clause = 1;
my %h_assign = ();
my %h_assign_new = ();
my $isFirstLoop = 1;

sub setVar{
	my $varName = @_[0];
	my $type = @_[1];

	if(!exists($h_var{$varName})){
		cnt("v", $type);
		$h_var{$varName} = $idx_var;
		$idx_var++;
	}
	return;
}
sub setVar_wo_cnt{
	my $varName = @_[0];
	my $type = @_[1];

	if(!exists($h_var{$varName})){
		$h_var{$varName} = -1;
	}
	return;
}

### Z3 Option Set ###
print $out ";Begin SMT Formulation\n\n";

print $out "(declare-const COST_SIZE (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";
print $out "(declare-const COST_SIZE_P (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";
print $out "(declare-const COST_SIZE_N (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";
for my $i (0 .. $numTrackH-3){
	print $out "(declare-const M2_TRACK_$i Bool)\n";
}
foreach my $key(sort(keys %h_extnets)){
	for my $i (0 .. $numTrackH-3){
		print $out "(declare-const N".$key."_M2_TRACK_$i Bool)\n";
	}
	print $out "(declare-const N".$key."_M2_TRACK Bool)\n";
}

### Placement ###
print "a   A. Variables for Placement\n";
print $out ";A. Variables for Placement\n";
print $out "(define-fun max ((x (_ BitVec ".(length(sprintf("%b", $numTrackV))+4).")) (y (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))) (_ BitVec ".(length(sprintf("%b", $numTrackV))+4).")\n";
print $out "  (ite (bvsgt x y) x y)\n";
print $out ")\n";

for my $i (0 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	print $out "(declare-const x$i (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";     # instance x position
	cnt("v", 0);
	print $out "(declare-const ff$i Bool)\n";    # instance flip flag
	cnt("v", 0);
	### just for solution converter
	print $out "(declare-const y$i (_ BitVec ".(length(sprintf("%b", $numPTrackH)))."))\n";     # instance y position
	print $out "(declare-const uw$i (_ BitVec ".(length(sprintf("%b", $trackEachPRow)))."))\n";	# unit width
	print $out "(declare-const w$i (_ BitVec ".(length(sprintf("%b", (2*$tmp_finger[0]+1))))."))\n";		# width
	print $out "(declare-const nf$i (_ BitVec ".(length(sprintf("%b", $tmp_finger[0])))."))\n";    # num of finger
}

print "a   B. Constraints for Placement\n";
print $out "\n";
print $out ";B. Constraints for Placement\n";

for my $i (0 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	my $len = length(sprintf("%b", $numTrackV))+4;
	my $len2 = length(sprintf("%b", 0));
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-$len2-1){
			$tmp_str.="0";
		}
	}
	my $s_first = "#b".$tmp_str."0";
	$len2 = length(sprintf("%b", $numPTrackV - 2*$tmp_finger[0] + 1));
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-$len2-1){
			$tmp_str.="0";
		}
	}
	my $s_second = "#b".$tmp_str.sprintf("%b", ($numPTrackV - 2*$tmp_finger[0]));
	print $out "(assert (and (bvsge x$i (_ bv0 $len)) (bvsle x$i (_ bv".($numPTrackV - 2*$tmp_finger[0] - 1)." $len))))\n";
	cnt("l", 0);
	cnt("l", 0);
	cnt("c", 0);
}
for my $i (0 .. $lastIdxPMOS) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	print $out "(assert (= y$i (_ bv".($numPTrackH-$inst[$i][2]/$tmp_finger[0])." ".length(sprintf("%b", $numPTrackH)).")))\n";
	print $out "(assert (= nf$i (_ bv".$tmp_finger[0]." ".length(sprintf("%b", $tmp_finger[0])).")))\n";
	print $out "(assert (= uw$i (_ bv".$inst[$i][2]/$tmp_finger[0]." ".(length(sprintf("%b", $trackEachPRow))).")))\n";
	print $out "(assert (= w$i (_ bv".(2*$tmp_finger[0]+1)." ".length(sprintf("%b", 2*$tmp_finger[0]+1)).")))\n";
}
for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	print $out "(assert (= y$i (_ bv0 ".length(sprintf("%b", $numPTrackH)).")))\n";
	print $out "(assert (= nf$i (_ bv".$tmp_finger[0]." ".length(sprintf("%b", $tmp_finger[0])).")))\n";
	print $out "(assert (= uw$i (_ bv".$inst[$i][2]/$tmp_finger[0]." ".(length(sprintf("%b", $trackEachPRow))).")))\n";
	print $out "(assert (= w$i (_ bv".(2*$tmp_finger[0]+1)." ".length(sprintf("%b", 2*$tmp_finger[0]+1)).")))\n";
}
for my $i (0 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	my $len = length(sprintf("%b", $numTrackV))+4;
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-2){
			$tmp_str.="0";
		}
	}
	print $out "(assert (= ((_ extract 0 0) x$i) #b1))\n";
	cnt("l", 0);
	cnt("c", 0);
}
my $tmp_minWidth = 0;
for my $i (0 .. $lastIdxPMOS) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	$tmp_minWidth+=2*$tmp_finger[0];
}
$minWidth = $tmp_minWidth;
$tmp_minWidth = 0;
for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	$tmp_minWidth+=2*$tmp_finger[0];
}
if($tmp_minWidth>$minWidth){
	$minWidth = $tmp_minWidth;
}

if($BS_Parameter == 1){
	print $out ";Removing Symmetric Placement Cases\n";
	my $numPMOS = $lastIdxPMOS + 1;
	my $numNMOS = $numInstance - $numPMOS;
	my @arr_pmos = ();
	my @arr_nmos = ();

	for my $i (0 .. $lastIdxPMOS){
		push(@arr_pmos, $i);
	}
	for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
		push(@arr_nmos, $i);
	}


	my @comb_l_pmos = ();
	my @comb_l_nmos = ();
	my @comb_c_pmos = ();
	my @comb_c_nmos = ();
	my @comb_r_pmos = ();
	my @comb_r_nmos = ();

	if($numPMOS % 2 == 0){
		my @tmp_comb_l_pmos = combine([@arr_pmos],$numPMOS/2);
		for my $i(0 .. $#tmp_comb_l_pmos){
			my @tmp_comb = ();
			my $isComb = 0;
			for my $j(0 .. $lastIdxPMOS){
				for my $k(0 .. $#{$tmp_comb_l_pmos[$i]}){
					if($tmp_comb_l_pmos[$i][$k] == $j){
						$isComb = 1;
						last;
					}
				}
				if($isComb == 0){
					push(@tmp_comb, $j);
				}
				$isComb = 0;
			}
			push(@comb_l_pmos, $tmp_comb_l_pmos[$i]);
			push(@comb_r_pmos, [@tmp_comb]);
			if($#tmp_comb_l_pmos == 1){
				last;
			}
		}
	}
	else{
		for my $m(0 .. $numPMOS - 1){
			@arr_pmos = ();
			for my $i (0 .. $lastIdxPMOS){
				if($i!=$m){
					push(@arr_pmos, $i);
				}
			}
			my @tmp_comb_l_pmos = combine([@arr_pmos],($numPMOS-1)/2);
			for my $i(0 .. $#tmp_comb_l_pmos){
				my @tmp_comb = ();
				my $isComb = 0;
				for my $j(0 .. $lastIdxPMOS){
					for my $k(0 .. $#{$tmp_comb_l_pmos[$i]}){
						if($tmp_comb_l_pmos[$i][$k] == $j || $j == $m){
							$isComb = 1;
							last;
						}
					}
					if($isComb == 0){
						push(@tmp_comb, $j);
					}
					$isComb = 0;
				}
				push(@comb_l_pmos, $tmp_comb_l_pmos[$i]);
				push(@comb_r_pmos, [@tmp_comb]);
				push(@comb_c_pmos, [($m)]);
				if($#tmp_comb_l_pmos == 1){
					last;
				}
			}
		}
	}
	if($numNMOS % 2 == 0){
		my @tmp_comb_l_nmos = combine([@arr_nmos],$numNMOS/2);
		for my $i(0 .. $#tmp_comb_l_nmos){
			my @tmp_comb = ();
			my $isComb = 0;
			for my $j ($lastIdxPMOS + 1 .. $numInstance - 1) {
				for my $k(0 .. $#{$tmp_comb_l_nmos[$i]}){
					if($tmp_comb_l_nmos[$i][$k] == $j){
						$isComb = 1;
						last;
					}
				}
				if($isComb == 0){
					push(@tmp_comb, $j);
				}
				$isComb = 0;
			}
			push(@comb_l_nmos, $tmp_comb_l_nmos[$i]);
			push(@comb_r_nmos, [@tmp_comb]);
			if($#comb_l_nmos == 1){
				last;
			}
		}
	}
	else{
		for my $m ($lastIdxPMOS + 1 .. $numInstance - 1) {
			@arr_nmos = ();
			for my $i (0 .. $numNMOS-1){
				if($i+$lastIdxPMOS+1!=$m){
					push(@arr_nmos, $i+$lastIdxPMOS+1);
				}
			}
			my @tmp_comb_l_nmos = combine([@arr_nmos],($numNMOS-1)/2);
			for my $i(0 .. $#tmp_comb_l_nmos){
				my @tmp_comb = ();
				my $isComb = 0;
				for my $j ($lastIdxPMOS + 1 .. $numInstance - 1) {
					for my $k(0 .. $#{$tmp_comb_l_nmos[$i]}){
						if($tmp_comb_l_nmos[$i][$k] == $j || $j == $m){
							$isComb = 1;
							last;
						}
					}
					if($isComb == 0){
						push(@tmp_comb, $j);
					}
					$isComb = 0;
				}
				push(@comb_l_nmos, $tmp_comb_l_nmos[$i]);
				push(@comb_r_nmos, [@tmp_comb]);
				push(@comb_c_nmos, [($m)]);
				if($#tmp_comb_l_nmos == 1){
					last;
				}
			}
		}
	}

	for my $i(0 .. $#comb_l_pmos){
		print $out "(assert (or";
		for my $l(0 .. $#{$comb_l_pmos[$i]}){
			for my $m(0 .. $#{$comb_r_pmos[$i]}){
				print $out " (bvslt x$comb_l_pmos[$i][$l] x$comb_r_pmos[$i][$m])";
				cnt("l", 0);
				for my $n(0 .. $#{$comb_c_pmos[$i]}){
					print $out " (bvslt x$comb_l_pmos[$i][$l] x$comb_c_pmos[$i][$n])";
					print $out " (bvsgt x$comb_r_pmos[$i][$m] x$comb_c_pmos[$i][$n])";
					cnt("l", 0);
					cnt("l", 0);
				}
			}
		}
		print $out "))\n";
		cnt("c", 0);
	}
	print $out ";Set flip status to false for FETs which have even numbered fingers\n";
	for my $i (0 .. $lastIdxPMOS) {
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		if($tmp_finger[0]%2==0){
			print $out "(assert (= ff$i false))\n";
			cnt("l", 0);
			cnt("c", 0);
		}
	}
	for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		if($tmp_finger[0]%2==0){
			print $out "(assert (= ff$i false))\n";
			cnt("l", 0);
			cnt("c", 0);
		}
	}
	print $out ";End of Symmetric Removal\n";
}


my @g_p_h1 = ();
my @g_p_h2 = ();
my @g_p_h3 = ();
my @g_n_h1 = ();
my @g_n_h2 = ();
my @g_n_h3 = ();
my $w_p_h1 = 0;
my $w_p_h2 = 0;
my $w_p_h3 = 0;
my $w_n_h1 = 0;
my $w_n_h2 = 0;
my $w_n_h3 = 0;
my %h_g_inst = ();
for my $i (0 .. $lastIdxPMOS) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	if($inst[$i][2]/$tmp_finger[0] == 1){
		push(@g_p_h1, $i);
		$w_p_h1+=2*$tmp_finger[0];
		$h_g_inst{$i} = 1;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 2){
		push(@g_p_h2, $i);
		$w_p_h2+=2*$tmp_finger[0];
		$h_g_inst{$i} = 2;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 3){
		push(@g_p_h3, $i);
		$w_p_h3+=2*$tmp_finger[0];
		$h_g_inst{$i} = 3;
	}
}
for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	if($inst[$i][2]/$tmp_finger[0] == 1){
		push(@g_n_h1, $i);
		$w_n_h1+=2*$tmp_finger[0];
		$h_g_inst{$i} = 1;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 2){
		push(@g_n_h2, $i);
		$w_n_h2+=2*$tmp_finger[0];
		$h_g_inst{$i} = 2;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 3){
		push(@g_n_h3, $i);
		$w_n_h3+=2*$tmp_finger[0];
		$h_g_inst{$i} = 3;
	}
}

for my $i (0 .. $lastIdxPMOS) {
	my $tmp_key_S_i = $h_pin_id{"$inst[$i][0]_S"};
	my $tmp_key_D_i = $h_pin_id{"$inst[$i][0]_D"};
	my @tmp_finger_i = ();
	@tmp_finger_i = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	my $height_i = $inst[$i][2]/$tmp_finger_i[0];

	if($XOL_Mode > 0){
		print $out "(declare-const fol_l_x$i Bool)\n";
		print $out "(declare-const fol_r_x$i Bool)\n";

		my $tmp_str_xol_l = "(assert (ite (not (or";
		my $tmp_str_xol_r = "(assert (ite (not (or";
		my $cnt_xol = 0;
		for my $k (0 .. $lastIdxPMOS) {
			my $len = length(sprintf("%b", $numTrackV))+4;
			if($k != $i){
				my $tmp_key_S_k = $h_pin_id{"$inst[$k][0]_S"};
				my $tmp_key_D_k = $h_pin_id{"$inst[$k][0]_D"};
				my @tmp_finger_k = ();
				@tmp_finger_k = getAvailableNumFinger($inst[$k][2], $trackEachPRow);
				my $height_k = $inst[$k][2]/$tmp_finger_k[0];

				if($NDE_Parameter == 0 && $height_i != $height_k){
					next;
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_k[0] % 2 == 0 && $tmp_key_S_i != $tmp_key_S_k){
					next;
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_k[0] % 2 == 1 && $tmp_key_S_i != $tmp_key_S_k && $tmp_key_S_i != $tmp_key_D_k){
					next;
				}
				elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_k[0] % 2 == 0 && $tmp_key_S_k != $tmp_key_S_i && $tmp_key_S_k != $tmp_key_D_i){
					next;
				}
				elsif($tmp_key_S_k != $tmp_key_S_i && $tmp_key_S_k != $tmp_key_D_i && $tmp_key_D_k != $tmp_key_S_i && $tmp_key_D_k != $tmp_key_D_i){
					next;
				}
				print $out "(assert (ite (= (bvadd x$i (_ bv".(2*$tmp_finger_i[0])." $len)) x$k) (= fol_r_x$i true) (= #b1 #b1)))\n";
				print $out "(assert (ite (= (bvsub x$i (_ bv".(2*$tmp_finger_k[0])." $len)) x$k) (= fol_l_x$i true) (= #b1 #b1)))\n";
				$tmp_str_xol_l.=" (= (bvadd x$i (_ bv".(2*$tmp_finger_i[0])." $len)) x$k)";
				$tmp_str_xol_r.=" (= (bvsub x$i (_ bv".(2*$tmp_finger_k[0])." $len)) x$k)";
				$cnt_xol++;
			}
		}
		$tmp_str_xol_l.=")) (= fol_r_x$i false) (= #b1 #b1)))\n";
		$tmp_str_xol_r.=")) (= fol_l_x$i false) (= #b1 #b1)))\n";
		if($cnt_xol>0){
			print $out $tmp_str_xol_l;
			print $out $tmp_str_xol_r;
		}
		else{
			print $out "(assert (= fol_r_x$i false))\n";
			print $out "(assert (= fol_l_x$i false))\n";
		}
	}

	for my $j (0 .. $lastIdxPMOS) {
		if($i != $j){
			my $tmp_key_S_j = $h_pin_id{"$inst[$j][0]_S"};
			my $tmp_key_D_j = $h_pin_id{"$inst[$j][0]_D"};
			my @tmp_finger_j = ();
			@tmp_finger_j = getAvailableNumFinger($inst[$j][2], $trackEachPRow);

			my $height_j = $inst[$j][2]/$tmp_finger_j[0];

			my $canShare = 1;
			if($NDE_Parameter == 0 && $height_i != $height_j){
				$canShare = 0;
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0 && $tmp_key_S_i != $tmp_key_S_j){
				$canShare = 0;
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1 && $tmp_key_S_i != $tmp_key_S_j && $tmp_key_S_i != $tmp_key_D_j){
				$canShare = 0;
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0 && $tmp_key_S_j != $tmp_key_S_i && $tmp_key_S_j != $tmp_key_D_i){
				$canShare = 0;
			}
			elsif($tmp_key_S_j != $tmp_key_S_i && $tmp_key_S_j != $tmp_key_D_i && $tmp_key_D_j != $tmp_key_S_i && $tmp_key_D_j != $tmp_key_D_i){
				$canShare = 0;
			}
			
			my $tmp_str_ij = "";
			my $tmp_str_ji = "";
			if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
				$tmp_str_ij = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
				$tmp_str_ji = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$j false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_D_j) (= $tmp_key_S_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "(= ff$j false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_D_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$i false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_D_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "(= ff$i false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_S_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
#				$tmp_str_ij = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_S_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$j 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (= $tmp_key_D_i $tmp_key_S_j))))";
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ij = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ij = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ij = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ij = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ij = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = ffj
								$tmp_str_ij = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ij = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj =0
								$tmp_str_ij = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ij = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0
								$tmp_str_ij = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ij = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0 and ffj=0
								$tmp_str_ij = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ij = "(= #b1 #b0)";
							}
						}
					}
				}
				# nli = nrj
#				$tmp_str_ji = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_D_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (= $tmp_key_S_i $tmp_key_D_j))))";
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ji = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ji = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ji = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ji = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ji = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = ffj
								$tmp_str_ji = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ji = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj =0
								$tmp_str_ji = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ji = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0
								$tmp_str_ji = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ji = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0 and ffj=0
								$tmp_str_ji = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ji = "(= #b1 #b0)";
							}
						}
					}
				}
			}
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $f_wi = "(_ bv".(2*$tmp_finger_i[0])." $len)";
			my $f_wj = "(_ bv".(2*$tmp_finger_j[0])." $len)";
			my $xol = "(_ bv".$XOL_Parameter." $len)";
			my $xol_i = "(_ bv".(2*$tmp_finger_i[0] + $XOL_Parameter)." $len)";
			my $xol_j = "(_ bv".(2*$tmp_finger_j[0] + $XOL_Parameter)." $len)";
			my $xol_i_o = "(_ bv".(2*$tmp_finger_i[0] + $XOL_Parameter - 2)." $len)";
			my $xol_j_o = "(_ bv".(2*$tmp_finger_j[0] + $XOL_Parameter - 2)." $len)";

			if($XOL_Mode > 0 && $lastIdxPMOS >= 2){
				print $out "(assert (ite (and fol_r_x$i (bvslt (bvadd x$i ".($f_wi).") x$j)) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
				if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
					# sourses of both inst are the same => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# sources of both inst are different => DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
					# source of inst i is same as source and drain of inst j => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# source of inst i is same as source of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i is same as drain of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$j $xol_i_o $xol_i)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
					# source of inst j is same as source and drain of inst i => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# source of inst j is same as source of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$i $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst j is same as drain of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$i) $xol_i_o $xol_i)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				else{
					# all source/drain are the same ==> SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# source/drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# source/drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$j $xol_i_o $xol_i)) x$j)\n";
					}
					# source/drain of inst j && source of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$i $xol_i_o $xol_i)) x$j)\n";
					}
					# source/drain of inst j && drain of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$i) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && source of inst j, drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (or (and (not ff$i) ff$j) (and ff$i (not ff$j))) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && drain of inst j, drain of inst i && source of inst j are the same => coinditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (or (and (not ff$i) (not ff$j)) (and ff$i ff$j)) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and ff$i (not ff$j)) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and ff$i ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and (not ff$i) (not ff$j)) $xol_i_o $xol_i)) x$j)\n";
					}
					# drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and (not ff$i) ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				if($canShare == 1){
					print $out "		(ite (and (= (bvadd x$i ".($f_wi).") x$j) $tmp_str_ij) (= (bvadd x$i ".($f_wi).") x$j)\n";
				}
				print $out "		(ite (and fol_l_x$i (bvsgt (bvsub x$i ".($f_wj).") x$j)) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
				if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
					# sourses of both inst are the same => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# sources of both inst are different => DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
					# source of inst i is same as source and drain of inst j => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# source of inst i is same as source of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$j $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i is same as drain of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
					# source of inst j is same as source and drain of inst i => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# source of inst j is same as source of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$i) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst j is same as drain of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$i $xol_j_o $xol_j)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				else{
					# all source/drain are the same ==> SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# source/drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$j $xol_j_o $xol_j)) x$j)\n";
					}
					# source/drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# source/drain of inst j && source of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$i) $xol_j_o $xol_j)) x$j)\n";
					}
					# source/drain of inst j && drain of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$i $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && source of inst j, drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (or (and (not ff$i) ff$j) (and ff$i (not ff$j))) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && drain of inst j, drain of inst i && source of inst j are the same => coinditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (or (and (not ff$i) (not ff$j)) (and ff$i ff$j)) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and (not ff$i) ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and (not ff$i) (not ff$j)) $xol_j_o $xol_j)) x$j)\n";
					}
					# drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and ff$i ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and ff$i (not ff$j)) $xol_j_o $xol_j)) x$j)\n";
					}
					# DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				if($canShare == 1){
					print $out "		(ite (and (= (bvsub x$i ".($f_wj).") x$j) $tmp_str_ji) (= (bvsub x$i ".($f_wj).") x$j)\n";
				}
				if($canShare == 1){
					print $out "		(= #b1 #b0))))))))\n";
				}
				else{
					print $out "		(= #b1 #b0))))))\n";
				}
			}
			else{
				if($canShare==1){
					print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					print $out "        (ite (and (= (bvadd x$i ".($f_wi).") x$j) $tmp_str_ij) (= (bvadd x$i ".($f_wi).") x$j)\n";
					print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					print $out "	    (ite (and (= (bvsub x$i ".($f_wj).") x$j) $tmp_str_ji) (= (bvsub x$i ".($f_wj).") x$j)\n";
					print $out "	    (= #b1 #b0))))))\n";
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("c", 0);
				}
				else{
					print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					print $out "	    (= #b1 #b0))))\n";
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("c", 0);
				}
			}
		}
	}
}
for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	my $tmp_key_S_i = $h_pin_id{"$inst[$i][0]_S"};
	my $tmp_key_D_i = $h_pin_id{"$inst[$i][0]_D"};
	my @tmp_finger_i = ();
	@tmp_finger_i = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	my $height_i = $inst[$i][2]/$tmp_finger_i[0];
	if($XOL_Mode > 0){
		print $out "(declare-const fol_l_x$i Bool)\n";
		print $out "(declare-const fol_r_x$i Bool)\n";

		my $tmp_str_xol_l = "(assert (ite (not (or";
		my $tmp_str_xol_r = "(assert (ite (not (or";
		my $cnt_xol = 0;
		for my $k ($lastIdxPMOS + 1 .. $numInstance - 1) {
			my $len = length(sprintf("%b", $numTrackV))+4;
			if($k != $i){
				my $tmp_key_S_k = $h_pin_id{"$inst[$k][0]_S"};
				my $tmp_key_D_k = $h_pin_id{"$inst[$k][0]_D"};
				my @tmp_finger_k = ();
				@tmp_finger_k = getAvailableNumFinger($inst[$k][2], $trackEachPRow);
				my $height_k = $inst[$k][2]/$tmp_finger_k[0];

				if($NDE_Parameter == 0 && $height_i != $height_k){
					next;
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_k[0] % 2 == 0 && $tmp_key_S_i != $tmp_key_S_k){
					next;
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_k[0] % 2 == 1 && $tmp_key_S_i != $tmp_key_S_k && $tmp_key_S_i != $tmp_key_D_k){
					next;
				}
				elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_k[0] % 2 == 0 && $tmp_key_S_k != $tmp_key_S_i && $tmp_key_S_k != $tmp_key_D_i){
					next;
				}
				elsif($tmp_key_S_k != $tmp_key_S_i && $tmp_key_S_k != $tmp_key_D_i && $tmp_key_D_k != $tmp_key_S_i && $tmp_key_D_k != $tmp_key_D_i){
					next;
				}
				print $out "(assert (ite (= (bvadd x$i (_ bv".(2*$tmp_finger_i[0])." $len)) x$k) (= fol_r_x$i true) (= #b1 #b1)))\n";
				print $out "(assert (ite (= (bvsub x$i (_ bv".(2*$tmp_finger_k[0])." $len)) x$k) (= fol_l_x$i true) (= #b1 #b1)))\n";
				$tmp_str_xol_l.=" (= (bvadd x$i (_ bv".(2*$tmp_finger_i[0])." $len)) x$k)";
				$tmp_str_xol_r.=" (= (bvsub x$i (_ bv".(2*$tmp_finger_k[0])." $len)) x$k)";
				$cnt_xol++;
			}
		}
		$tmp_str_xol_l.=")) (= fol_r_x$i false) (= #b1 #b1)))\n";
		$tmp_str_xol_r.=")) (= fol_l_x$i false) (= #b1 #b1)))\n";
		if($cnt_xol>0){
			print $out $tmp_str_xol_l;
			print $out $tmp_str_xol_r;
		}
		else{
			print $out "(assert (= fol_r_x$i false))\n";
			print $out "(assert (= fol_l_x$i false))\n";
		}
	}

	for my $j ($lastIdxPMOS + 1 .. $numInstance - 1) {
		if($i != $j){
			my $tmp_key_S_j = $h_pin_id{"$inst[$j][0]_S"};
			my $tmp_key_D_j = $h_pin_id{"$inst[$j][0]_D"};
			my @tmp_finger_j = ();
			@tmp_finger_j = getAvailableNumFinger($inst[$j][2], $trackEachPRow);
			
			my $height_j = $inst[$j][2]/$tmp_finger_j[0];

			my $canShare = 1;
			if($NDE_Parameter == 0 && $height_i != $height_j){
				$canShare = 0;
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0 && $tmp_key_S_i != $tmp_key_S_j){
				$canShare = 0;
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1 && $tmp_key_S_i != $tmp_key_S_j && $tmp_key_S_i != $tmp_key_D_j){
				$canShare = 0;
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0 && $tmp_key_S_j != $tmp_key_S_i && $tmp_key_S_j != $tmp_key_D_i){
				$canShare = 0;
			}
			elsif($tmp_key_S_j != $tmp_key_S_i && $tmp_key_S_j != $tmp_key_D_i && $tmp_key_D_j != $tmp_key_S_i && $tmp_key_D_j != $tmp_key_D_i){
				$canShare = 0;
			}

			my $tmp_str_ij = "";
			my $tmp_str_ji = "";
			if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
				$tmp_str_ij = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
				$tmp_str_ji = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$j false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_D_j) (= $tmp_key_S_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "(= ff$j false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_D_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$i false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_D_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "(= ff$i false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_S_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
#				$tmp_str_ij = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_S_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$j 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (= $tmp_key_D_i $tmp_key_S_j))))";
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ij = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ij = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ij = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ij = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ij = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = ffj
								$tmp_str_ij = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ij = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj =0
								$tmp_str_ij = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ij = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0
								$tmp_str_ij = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ij = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0 and ffj=0
								$tmp_str_ij = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ij = "(= #b1 #b0)";
							}
						}
					}
				}
				# nli = nrj
#				$tmp_str_ji = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_D_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (= $tmp_key_S_i $tmp_key_D_j))))";
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ji = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ji = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ji = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ji = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ji = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = ffj
								$tmp_str_ji = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ji = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj =0
								$tmp_str_ji = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ji = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0
								$tmp_str_ji = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ji = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0 and ffj=0
								$tmp_str_ji = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ji = "(= #b1 #b0)";
							}
						}
					}
				}
			}
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $f_wi = "(_ bv".(2*$tmp_finger_i[0])." $len)";
			my $f_wj = "(_ bv".(2*$tmp_finger_j[0])." $len)";
			my $xol = "(_ bv".$XOL_Parameter." $len)";
			my $xol_i = "(_ bv".(2*$tmp_finger_i[0] + $XOL_Parameter)." $len)";
			my $xol_j = "(_ bv".(2*$tmp_finger_j[0] + $XOL_Parameter)." $len)";
			my $xol_i_o = "(_ bv".(2*$tmp_finger_i[0] + $XOL_Parameter - 2)." $len)";
			my $xol_j_o = "(_ bv".(2*$tmp_finger_j[0] + $XOL_Parameter - 2)." $len)";

			if($NDE_Parameter == 1){
				$height_i = $height_j;
			}

			if($XOL_Mode > 0 && $numInstance - 1 - $lastIdxPMOS - 1 >= 2){
				print $out "(assert (ite (and fol_r_x$i (bvslt (bvadd x$i ".($f_wi).") x$j)) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
				if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
					# sourses of both inst are the same => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# sources of both inst are different => DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
					# source of inst i is same as source and drain of inst j => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# source of inst i is same as source of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i is same as drain of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$j $xol_i_o $xol_i)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
					# source of inst j is same as source and drain of inst i => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# source of inst j is same as source of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$i $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst j is same as drain of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$i) $xol_i_o $xol_i)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				else{
					# all source/drain are the same ==> SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i_o) x$j)\n";
					}
					# source/drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# source/drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$j $xol_i_o $xol_i)) x$j)\n";
					}
					# source/drain of inst j && source of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite ff$i $xol_i_o $xol_i)) x$j)\n";
					}
					# source/drain of inst j && drain of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (not ff$i) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && source of inst j, drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (or (and (not ff$i) ff$j) (and ff$i (not ff$j))) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && drain of inst j, drain of inst i && source of inst j are the same => coinditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (or (and (not ff$i) (not ff$j)) (and ff$i ff$j)) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and ff$i (not ff$j)) $xol_i_o $xol_i)) x$j)\n";
					}
					# source of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and ff$i ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and (not ff$i) (not ff$j)) $xol_i_o $xol_i)) x$j)\n";
					}
					# drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i (ite (and (not ff$i) ff$j) $xol_i_o $xol_i)) x$j)\n";
					}
					# DDB
					else{
						print $out "		(ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					}
				}
				if($canShare == 1){
					print $out "		(ite (and (= (bvadd x$i ".($f_wi).") x$j) $tmp_str_ij) (= (bvadd x$i ".($f_wi).") x$j)\n";
				}
				print $out "		(ite (and fol_l_x$i (bvsgt (bvsub x$i ".($f_wj).") x$j)) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
				if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
					# sourses of both inst are the same => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# sources of both inst are different => DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
					# source of inst i is same as source and drain of inst j => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# source of inst i is same as source of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$j $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i is same as drain of inst j => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
					# source of inst j is same as source and drain of inst i => SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# source of inst j is same as source of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$i) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst j is same as drain of inst i => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$i $xol_j_o $xol_j)) x$j)\n";
					}
					# no source/drain is same between inst i/j => DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				else{
					# all source/drain are the same ==> SDB
					if($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j_o) x$j)\n";
					}
					# source/drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$j $xol_j_o $xol_j)) x$j)\n";
					}
					# source/drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_i && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# source/drain of inst j && source of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_S_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (not ff$i) $xol_j_o $xol_j)) x$j)\n";
					}
					# source/drain of inst j && drain of inst i are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_j == $tmp_key_D_j && $tmp_key_S_j == $tmp_key_D_i){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite ff$i $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && source of inst j, drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (or (and (not ff$i) ff$j) (and ff$i (not ff$j))) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && drain of inst j, drain of inst i && source of inst j are the same => coinditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (or (and (not ff$i) (not ff$j)) (and ff$i ff$j)) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and (not ff$i) ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# source of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_S_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and (not ff$i) (not ff$j)) $xol_j_o $xol_j)) x$j)\n";
					}
					# drain of inst i && source of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_S_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and ff$i ff$j) $xol_j_o $xol_j)) x$j)\n";
					}
					# drain of inst i && drain of inst j are the same => conditional SDB/DDB
					elsif($XOL_Mode==2 && (exists($h_sdbcell{$i}) && exists($h_sdbcell{$j})) && $tmp_key_D_i == $tmp_key_D_j){
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i (ite (and ff$i (not ff$j)) $xol_j_o $xol_j)) x$j)\n";
					}
					# DDB
					else{
						print $out "		(ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					}
				}
				if($canShare == 1){
					print $out "		(ite (and (= (bvsub x$i ".($f_wj).") x$j) $tmp_str_ji) (= (bvsub x$i ".($f_wj).") x$j)\n";
				}
				if($canShare == 1){
					print $out "		(= #b1 #b0))))))))\n";
				}
				else{
					print $out "		(= #b1 #b0))))))\n";
				}
			}
			else{
				if($canShare==1){
					print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					print $out "        (ite (and (= (bvadd x$i ".($f_wi).") x$j) $tmp_str_ij) (= (bvadd x$i ".($f_wi).") x$j)\n";
					print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					print $out "	    (ite (and (= (bvsub x$i ".($f_wj).") x$j) $tmp_str_ji) (= (bvsub x$i ".($f_wj).") x$j)\n";
					print $out "	    (= #b1 #b0))))))\n";
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("c", 0);
				}
				else{
					print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
					print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
					print $out "	    (= #b1 #b0))))\n";
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("l", 0);
					cnt("c", 0);
				}
			}
		}
	}
}
print $out "\n";

### Routing ###
print "a   C. Variables for Routing\n";

print "a   D. Constraints for Routing\n";

### SOURCE and SINK DEFINITION per NET per COMMODITY and per VERTEX (including supernodes, i.e., pins)
### Preventing from routing Source/Drain Node using M1 Layer. Only Gate Node can use M1 between PMOS/NMOS Region
### UNDIRECTED_EDGE [index] [Term1] [Term2] [Cost]
#";Source/Drain Node between PMOS/NMOS region can not connect using M1 Layer.\n\n";
for my $udeIndex (0 .. $#udEdges) {
    my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
    my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
    my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
    my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
    my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
    my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
	if($fromCol % 2 == 1 || $toCol %2 == 1){
		if($fromMetal == 1 && $toMetal == 1){
			$h_assign{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"} = 0;
		}
	}
}
for my $netIndex (0 .. $#nets) {
    for my $udeIndex (0 .. $#udEdges) {
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
		my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
		my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		if($fromCol % 2 == 1 || $toCol %2 == 1){
			if($fromMetal == 1 && $toMetal == 1){
				$h_assign{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"} = 0;
			}
		}
    }
}
for my $netIndex (0 .. $#nets) {
    for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
        for my $udeIndex (0 .. $#udEdges) {
			my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
			my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
			my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
			my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
			my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
			my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
			if($fromCol % 2 == 1 || $toCol %2 == 1){
				if($fromMetal == 1 && $toMetal == 1){
					$h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"} = 0;
				}
			}
		}
    }
}

### Extensible Boundary variables
# In Extensible Case , Metal binary variables
if ($BoundaryCondition == 1){
}
else{
#$str.="; There are no adjacent vertices in L, R, F, B directions.\n\n";
	for my $leftVertex (0 .. $#leftCorners) {
		my $metal = (split /[a-z]/, $leftCorners[$leftVertex])[1];
		if ($metal % 2 == 0) {
			$h_assign{"M_LeftEnd_$leftCorners[$leftVertex]"} = 0;
		}
	}
	for my $rightVertex (0 .. $#rightCorners) {
		my $metal = (split /[a-z]/, $rightCorners[$rightVertex])[1];
		if ($metal % 2 == 0) {
			$h_assign{"M_$rightCorners[$rightVertex]_RightEnd"} = 0;
		}
	}
	for my $frontVertex (0 .. $#frontCorners) {
		my $metal = (split /[a-z]/, $frontCorners[$frontVertex])[1];
		if ($metal % 2 == 1) {
			$h_assign{"M_FrontEnd_$frontCorners[$frontVertex]"} = 0;
		}
	}
	for my $backVertex (0 .. $#backCorners) {
		my $metal = (split /[a-z]/, $backCorners[$backVertex])[1];
		if ($metal % 2 == 1) {
			$h_assign{"M_$backCorners[$backVertex]_BackEnd"} = 0;
		}
	}
}
### Commodity Flow binary variables
for my $netIndex (0 .. $#nets) {
	for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
		for my $vEdgeIndex (0 .. $#virtualEdges) {
			my $tmp_vname = "";
			if ($virtualEdges[$vEdgeIndex][2] =~ /^pin/) { # source
				if ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
					if($pins[$h_pinId_idx{$nets[$netIndex][3]}][7] eq "G"){ ### GATE Pin
						my $col = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3]; # 1:metal 2:row 3:col
						if($col % 2 == 0){
						}
						else{
							$h_assign{"N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"} = 0;
						}
					}
					else{
						my $col = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3]; # 1:metal 2:row 3:col
						if($col % 2 == 1){
						}
						else{
							$h_assign{"N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"} = 0;
						}
					}
				}
				elsif ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
					if(!($virtualEdges[$vEdgeIndex][2] eq $keySON)){
						if($pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7] eq "G"){ ### GATE Pin
							my $col = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3]; # 1:metal 2:row 3:col
							if($col % 2 == 0){
							}
							else{
								$h_assign{"N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"} = 0;
							}
						}
						else{
							my $col = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3]; # 1:metal 2:row 3:col
							if($col % 2 == 1){
							}
							else{
								$h_assign{"N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"} = 0;
							}
						}
					}
				}
			}
		}
	}
}
if($Local_Parameter == 1){
	$str.=";Localization.\n\n";
	$str.=";Localization for Adjacent Pins in the same multifinger TRs.\n\n";
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			my $inst_pin_s = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][3]}][6]};
			my $inst_pin_t = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][6]};
			my $type_s = $pins[$h_pinId_idx{$nets[$netIndex][3]}][7];
			my $type_t = $pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7];
			my $pidx_s = $nets[$netIndex][3];
			my $pidx_t = $nets[$netIndex][5][$commodityIndex];
			my @finger_s = getAvailableNumFinger($inst[$inst_pin_s][2], $trackEachPRow);
			my @finger_t = getAvailableNumFinger($inst[$inst_pin_t][2], $trackEachPRow);
			my $w_s = $finger_s[0]*2;
			my $w_t = $finger_t[0]*2;
			my $len = length(sprintf("%b", $numTrackV))+4;
			$pidx_s =~ s/pin\S+_(\d+)/\1/g;
			$pidx_t =~ s/pin\S+_(\d+)/\1/g;
			my %h_edge = ();
			if($nets[$netIndex][5][$commodityIndex] ne $keySON){
				if($inst_pin_s == $inst_pin_t){
					for my $metal (3 .. $numMetalLayer) { 
						for my $col (0 .. $numTrackV-1){
							for my $row (0 .. $numTrackH-3) {
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										$h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 0;
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][1]"})){
										$h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 0;
									}
								}
							}
						}
					}
					if($type_s ne "G" && $type_t ne "G"){
						for my $metal (1 .. 2) { 
							for my $col (0 .. $numTrackV-1){
								my $r_l = 0;
								my $r_u = $numTrackH-3;
								if($inst_pin_s <= $lastIdxPMOS){
									$r_l = $numTrackH/2-1;
									$r_u = $numTrackH-3;
								}
								else{
									$r_l = 0;
									$r_u = $numTrackH/2-2;
								}
								for my $row ($r_l .. $r_u) {
									if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
										next;
									}
									my $vName = "m".$metal."r".$row."c".$col;
									my $vName2 = "m".$metal."r".($row-1)."c".$col;
									for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
#										if($vName2 eq $udEdges[$edge_in{$vName}[$i]][1]) { next;}
										if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											$h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 0;
										}
									}
									$vName2 = "m".$metal."r".($row+1)."c".$col;
									for my $i (0 .. $#{$edge_out{$vName}}){ # outgoing
#										if($vName2 eq $udEdges[$edge_out{$vName}[$i]][2]) { next;}
										if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											$h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 0;
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

my $isEnd = 0;
my $numLoop = 0;
print "\n";
my $pre_c_v_placement = $c_v_placement;
my $pre_c_v_placement_aux = $c_v_placement_aux;
my $pre_c_v_routing = $c_v_routing;
my $pre_c_v_routing_aux = $c_v_routing_aux;
my $pre_c_v_connect = $c_v_connect;
my $pre_c_v_connect_aux = $c_v_connect_aux;
my $pre_c_v_dr = $c_v_dr;
my $pre_c_c_placement = $c_c_placement;
my $pre_c_c_routing = $c_c_routing;
my $pre_c_c_connect = $c_c_connect;
my $pre_c_c_dr = $c_c_dr;
my $pre_c_l_placement = $c_l_placement;
my $pre_c_l_routing = $c_l_routing;
my $pre_c_l_connect = $c_l_connect;
my $pre_c_l_dr = $c_l_dr;
while($isEnd == 0){
	if((keys %h_assign_new) > 0){
		## Merge Assignment Information
		foreach my $key(sort(keys %h_assign_new)){
			$h_assign{$key} = $h_assign_new{$key};
		}
		%h_assign_new = ();
	}
	
	if($numLoop == 0){
		print "a    Initial SMT Code Generation\n";
	}
	else{
		print "a    SMT Code Reduction Loop #$numLoop\n";
	}

	$c_v_placement = $pre_c_v_placement;
	$c_v_placement_aux = $pre_c_v_placement_aux;
	$c_v_routing = $pre_c_v_routing;
	$c_v_routing_aux = $pre_c_v_routing_aux;
	$c_v_connect = $pre_c_v_connect;
	$c_v_connect_aux = $pre_c_v_connect_aux;
	$c_v_dr = $pre_c_v_dr;
	$c_c_placement = $pre_c_c_placement;
	$c_c_routing = $pre_c_c_routing;
	$c_c_connect = $pre_c_c_connect;
	$c_c_dr = $pre_c_c_dr;
	$c_l_placement = $pre_c_l_placement;
	$c_l_routing = $pre_c_l_routing;
	$c_l_connect = $pre_c_l_connect;
	$c_l_dr = $pre_c_l_dr;
	$str = "";
	%h_var = ();
	$idx_var = 1;

### Set Default Gate Metal according to the capacity variables
	my %h_tmp = ();
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			for my $vEdgeIndex (0 .. $#virtualEdges) {
				my $tmp_vname = "";
				my $tmp_vname1 = "";
				my $tmp_vname2 = "";
				if ($virtualEdges[$vEdgeIndex][2] =~ /^pin/) { # source
					if ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
						my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][3]}][6]};
						my @tmp_finger = ();
						@tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);
						my $height = 4;
						if($pins[$h_pinId_idx{$nets[$netIndex][3]}][7] eq "G"){ ### GATE Pin
							my $col = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3]; # 1:metal 2:row 3:col
							if($col % 2 == 0){
								$tmp_vname = $virtualEdges[$vEdgeIndex][1];
								$tmp_vname1 = $tmp_vname;
								$tmp_vname2 = $tmp_vname;
								$tmp_vname =~ s/m[0-9](.*)/ve_N$nets[$netIndex][1]\_C$commodityIndex\_E_\1_$virtualEdges[$vEdgeIndex][2]/g;
								if($instIdx <= $lastIdxPMOS){
									for my $i(0 .. $height-2){
										my $j=0+$i;
										my $k=$j+1;
										$tmp_vname1 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$j\\c\3/g;
										$tmp_vname1 =~ s/\\//g;
										$tmp_vname2 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$k\\c\3/g;
										$tmp_vname2 =~ s/\\//g;
										if(!exists($h_tmp{$tmp_vname1.$tmp_vname2})){
											if(!exists($h_assign{"M_$tmp_vname1\_$tmp_vname2"})){
												setVar("M_$tmp_vname1\_$tmp_vname2", 2);
												my $len = length(sprintf("%b", $numTrackV))+4;
												$str.="(assert (ite (bvsge COST_SIZE (_ bv".($col>0?($col-1):$col)." $len)) (= M_$tmp_vname1\_$tmp_vname2 true) (= M_$tmp_vname1\_$tmp_vname2 false)))\n";
												$h_tmp{$tmp_vname1.$tmp_vname2} = 1;
												cnt("l", 1);
												cnt("l", 1);
												cnt("l", 1);
												cnt("c", 1);
											}
										}
									}
								}
								else{
									for my $i(0 .. $height-2){
										my $j=$numTrackH - 2 - $height + $i;
										my $k=$j+1;
										$tmp_vname1 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$j\\c\3/g;
										$tmp_vname1 =~ s/\\//g;
										$tmp_vname2 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$k\\c\3/g;
										$tmp_vname2 =~ s/\\//g;
										if(!exists($h_tmp{$tmp_vname1.$tmp_vname2})){
											if(!exists($h_assign{"M_$tmp_vname1\_$tmp_vname2"})){
												setVar("M_$tmp_vname1\_$tmp_vname2", 2);
												my $len = length(sprintf("%b", $numTrackV))+4;
												$str.="(assert (ite (bvsge COST_SIZE (_ bv".($col>0?($col-1):$col)." $len)) (= M_$tmp_vname1\_$tmp_vname2 true) (= M_$tmp_vname1\_$tmp_vname2 false)))\n";
												$h_tmp{$tmp_vname1.$tmp_vname2} = 1;
												cnt("l", 1);
												cnt("l", 1);
												cnt("l", 1);
												cnt("c", 1);
											}
										}
									}
								}
							}
						}
					}
					elsif ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
						if(!($virtualEdges[$vEdgeIndex][2] eq $keySON)){
							my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][6]};
							my @tmp_finger = ();
							@tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);
							my $height = 3;
							if($pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7] eq "G"){ ### GATE Pin
								my $col = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3]; # 1:metal 2:row 3:col
								if($col % 2 == 0){
									$tmp_vname = $virtualEdges[$vEdgeIndex][1];
									$tmp_vname1 = $tmp_vname;
									$tmp_vname2 = $tmp_vname;
									$tmp_vname =~ s/m[0-9](.*)/ve_N$nets[$netIndex][1]\_C$commodityIndex\_E_\1_$virtualEdges[$vEdgeIndex][2]/g;
									if($instIdx <= $lastIdxPMOS){
										for my $i(0 .. $height-2){
											my $j=0+$i;
											my $k=$j+1;
											$tmp_vname1 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$j\\c\3/g;
											$tmp_vname1 =~ s/\\//g;
											$tmp_vname2 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$k\\c\3/g;
											$tmp_vname2 =~ s/\\//g;
											if(!exists($h_tmp{$tmp_vname1.$tmp_vname2})){
												if(!exists($h_assign{"M_$tmp_vname1\_$tmp_vname2"})){
													setVar("M_$tmp_vname1\_$tmp_vname2", 2);
													my $len = length(sprintf("%b", $numTrackV))+4;
													$str.="(assert (ite (bvsge COST_SIZE (_ bv".($col>0?($col-1):$col)." $len)) (= M_$tmp_vname1\_$tmp_vname2 true) (= M_$tmp_vname1\_$tmp_vname2 false)))\n";
													$h_tmp{$tmp_vname1.$tmp_vname2} = 1;
													cnt("l", 1);
													cnt("l", 1);
													cnt("l", 1);
													cnt("c", 1);
												}
											}
										}
									}
									else{
										for my $i(0 .. $height-2){
											my $j=$numTrackH - 2 - $height + $i;
											my $k=$j+1;
											$tmp_vname1 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$j\\c\3/g;
											$tmp_vname1 =~ s/\\//g;
											$tmp_vname2 =~ s/m(\d+)r(\d+)c(\d+)/m\1r$k\\c\3/g;
											$tmp_vname2 =~ s/\\//g;
											if(!exists($h_tmp{$tmp_vname1.$tmp_vname2})){
												if(!exists($h_assign{"M_$tmp_vname1\_$tmp_vname2"})){
													setVar("M_$tmp_vname1\_$tmp_vname2", 2);
													my $len = length(sprintf("%b", $numTrackV))+4;
													$str.="(assert (ite (bvsge COST_SIZE (_ bv".($col>0?($col-1):$col)." $len)) (= M_$tmp_vname1\_$tmp_vname2 true) (= M_$tmp_vname1\_$tmp_vname2 false)))\n";
													$h_tmp{$tmp_vname1.$tmp_vname2} = 1;
													cnt("l", 1);
													cnt("l", 1);
													cnt("l", 1);
													cnt("c", 1);
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	$str.=";Unset All Metal/Net/Wire over the rightmost cell/metal(>COST_SIZE+1)\n";
# Unset All Metal/Net/Wire over the rightmost cell/metal(>COST_SIZE+1)
	for my $udeIndex (0 .. $#udEdges) {
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
		my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
		my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $len = length(sprintf("%b", $numTrackV))+4;
		if($minWidth>2 && $toCol > $minWidth-2){
			if(!exists($h_assign{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				setVar("M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]", 2);
				$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] false) (= true true)))\n";
				cnt("l", 1);
				cnt("l", 1);
				cnt("c", 1);
			}
		}
	}
	for my $netIndex (0 .. $#nets) {
		for my $udeIndex (0 .. $#udEdges) {
			my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
			my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
			my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
			my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
			my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
			my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
			my $len = length(sprintf("%b", $numTrackV))+4;
			if($minWidth>2 && $toCol > $minWidth-2){
				if(!exists($h_assign{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
					setVar("N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]", 2);
					$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= N$nets[$netIndex][1]\_";
					$str.="E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] false) (= true true)))\n";
					cnt("l", 1);
					cnt("l", 1);
					cnt("c", 1);
				}
			}
		}
	}
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			for my $udeIndex (0 .. $#udEdges) {
				my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
				my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
				my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
				my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
				my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
				my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
				my $len = length(sprintf("%b", $numTrackV))+4;
				if($minWidth>2 && $toCol > $minWidth-2){
					if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]", 2);
						$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= N$nets[$netIndex][1]\_";
						$str.="C$commodityIndex\_";
						$str.="E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] false) (= true true)))\n";
						cnt("l", 1);
						cnt("l", 1);
						cnt("c", 1);
					}
				}
			}
		}
	}
	for my $vEdgeIndex (0 .. $#virtualEdges) {
		my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
		my $len = length(sprintf("%b", $numTrackV))+4;
		if($minWidth>2 && $toCol > $minWidth-2){
			if(!exists($h_assign{"M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"})){
				setVar("M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]", 2);
				$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] false) (= true true)))\n";
				cnt("l", 1);
				cnt("l", 1);
				cnt("c", 1);
			}
		}
	}
	for my $netIndex (0 .. $#nets) {
		for my $vEdgeIndex (0 .. $#virtualEdges) {
			my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
			my $len = length(sprintf("%b", $numTrackV))+4;
			if($minWidth>2 && $toCol > $minWidth-2){
				if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
					if(!exists($h_assign{"N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"})){
						setVar("N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]", 2);
						$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] false) (= true true)))\n";
						cnt("l", 1);
						cnt("l", 1);
						cnt("c", 1);
					}
				}
				else{
					for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
						if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
							if(!exists($h_assign{"N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"})){
								setVar("N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]", 2);
								$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] false) (= true true)))\n";
								cnt("l", 1);
								cnt("l", 1);
								cnt("c", 1);
							}
						}
					}
				}
			}
		}
	}
	for my $netIndex (0 .. $#nets) {
		for my $vEdgeIndex (0 .. $#virtualEdges) {
			my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
			my $fromMetal = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[1]; # 1:metal 2:row 3:col
			my $toMetal = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[1];
			my $len = length(sprintf("%b", $numTrackV))+4;
			if($minWidth>2 && $toCol > $minWidth-2){
				for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
					if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
						if(!exists($h_assign{"N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"})){
							setVar("N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]", 2);
							$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] false) (= true true)))\n";
							cnt("l", 1);
							cnt("l", 1);
							cnt("c", 1);
						}
					}
					if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
						if(!exists($h_assign{"N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]"})){
							setVar("N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]", 2);
							$str.="(assert (ite (bvsle COST_SIZE (_ bv".($toCol-2)." $len)) (= N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] false) (= true true)))\n";
							cnt("l", 1);
							cnt("l", 1);
							cnt("c", 1);
						}
					}
				}
			}
		}
	}
	my $numTrackAssign = keys %h_net_track;
	if($numTrackAssign>0){
		$str.=";Set Special Net Constraints\n";
		foreach my $key_i(keys %h_net_track){
			my $netIndex_i = $key_i;
			foreach my $key_j(keys %h_net_track){
				if($key_i!=$key_j){
					my $netIndex_j = $key_j;
					for my $row (0 .. $numTrackH-3-1){
						for my $col (0 .. $numTrackV-1-$ML_Parameter){
							my $tmp_str = "";
							if($ML_Parameter >= 2){
								$tmp_str="(assert ((_ at-least 1)"
							}
							else{
								$tmp_str="(assert (=";
							}
							for my $col2 ($col .. $col+$ML_Parameter-1){
								$tmp_str.=" (or";
								for my $udeIndex (0 .. $#udEdges) {
									my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
									my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
									my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
									my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
									if($fromMetal==2 && $toMetal == 2 && $fromRow == $row && $toCol == $col2+1){
										if(!exists($h_assign{"N$netIndex_i\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
											setVar("N$netIndex_i\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]", 2);
											$tmp_str.=" (not N$netIndex_i\_";
											$tmp_str.="E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2])";
										}
									}
									elsif($fromMetal==2 && $toMetal == 2 && $fromRow == ($row+1) && $toCol == $col2+1){
										if(!exists($h_assign{"N$netIndex_j\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
											setVar("N$netIndex_j\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]", 2);
											$tmp_str.=" (not N$netIndex_j\_";
											$tmp_str.="E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2])";
										}
									}
								}
								$tmp_str.=")";
							}
							if($ML_Parameter >= 2){
								$tmp_str.="))\n";
							}
							else{
								$tmp_str.=" true))\n";
							}
							$str.=$tmp_str;
						}
					}
				}
			}
		}
		foreach my $key_i(keys %h_net_track){
			my $netIndex_i = $key_i;
			foreach my $key_j(keys %h_net_track){
				if($key_i!=$key_j){
					my $netIndex_j = $key_j;
					for my $row (0 .. $numTrackH-3-1){
						for my $col (0 .. $numTrackV-1-$ML_Parameter){
							my $tmp_str = "";
							if($ML_Parameter >= 2){
								$tmp_str="(assert ((_ at-least 1)"
							}
							else{
								$tmp_str="(assert (=";
							}
							for my $col2 ($col .. $col+$ML_Parameter-1){
								$tmp_str.=" (or";
								for my $udeIndex (0 .. $#udEdges) {
									my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
									my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
									my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
									my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
									if($fromMetal==4 && $toMetal == 4 && $fromRow == $row && $toCol == $col2+1){
										if(!exists($h_assign{"N$netIndex_i\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
											setVar("N$netIndex_i\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]", 2);
											$tmp_str.=" (not N$netIndex_i\_";
											$tmp_str.="E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2])";
										}
									}
									elsif($fromMetal==4 && $toMetal == 4 && $fromRow == ($row+1) && $toCol == $col2+1){
										if(!exists($h_assign{"N$netIndex_j\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
											setVar("N$netIndex_j\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]", 2);
											$tmp_str.=" (not N$netIndex_j\_";
											$tmp_str.="E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2])";
										}
									}
								}
								$tmp_str.=")";
							}
							if($ML_Parameter >= 2){
								$tmp_str.="))\n";
							}
							else{
								$tmp_str.=" true))\n";
							}
							$str.=$tmp_str;
						}
					}
				}
			}
		}

		$str.=";End of Special Net Constraints\n";
	}

	if($Partition_Parameter == 1){
		$str.=";Set Partition Constraints\n";
		my $len = length(sprintf("%b", $numTrackV))+4;
		# Lower Group => Right Side
		for my $i(0 .. $#inst_group_p-1){
			my $minBound = 1;
			my $maxBound = $numTrackV;
			# PMOS
			for my $j($i+1 .. $#inst_group_p){
				for my $k(0 .. $#{$inst_group_p[$i][1]}){
					for my $l(0 .. $#{$inst_group_p[$j][1]}){
						$str.="(assert (bvsgt x$inst_group_p[$i][1][$k] x$inst_group_p[$j][1][$l]))\n";
					}
				}
				$minBound+=$inst_group_p[$j][2];
			}
			for my $j(0 .. $i-1){
				$maxBound-=$inst_group_p[$j][2];
			}
			for my $k(0 .. $#{$inst_group_p[$i][1]}){
				$str.="(assert (bvsge x$inst_group_p[$i][1][$k] (_ bv$minBound $len)))\n";
				$str.="(assert (bvsle x$inst_group_p[$i][1][$k] (_ bv$maxBound $len)))\n";
			}
		}
		for my $i(0 .. $#inst_group_n-1){
			my $minBound = 1;
			my $maxBound = $numTrackV;
			# NMOS
			for my $j($i+1 .. $#inst_group_n){
				for my $k(0 .. $#{$inst_group_n[$i][1]}){
					for my $l(0 .. $#{$inst_group_n[$j][1]}){
						$str.="(assert (bvsgt x$inst_group_n[$i][1][$k] x$inst_group_n[$j][1][$l]))\n";
					}
				}
				$minBound+=$inst_group_n[$j][2];
			}
			for my $j(0 .. $i-1){
				$maxBound-=$inst_group_n[$j][2];
			}
			for my $k(0 .. $#{$inst_group_n[$i][1]}){
				$str.="(assert (bvsge x$inst_group_n[$i][1][$k] (_ bv$minBound $len)))\n";
				$str.="(assert (bvsle x$inst_group_n[$i][1][$k] (_ bv$maxBound $len)))\n";
			}
		}
		$str.=";End of Partition Constraints\n";
	}

	$str.=";Set Initial Value for Gate Pins of P/N FET in the same column\n";
	## Set Initial Value for Gate Pins of P/N FET in the same column
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			my $tmp_vname = "";
			my $vName = "";
			my $startIdx = 0;
			my $endIdx = 0;
			my $instIdx_s = 0;
			my $instIdx_t = 0;
			my @tmp_finger_s = ();
			my @tmp_finger_t = ();
			my $row_s = 0;
			my $row_t = 0;

			## Source MaxFlow Indicator
			$instIdx_s = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][3]}][6]};
			@tmp_finger_s = getAvailableNumFinger($inst[$instIdx_s][2], $trackEachPRow);
			## Sink MaxFlow Indicator
			if($nets[$netIndex][5][$commodityIndex] eq $keySON){
				next;
			}
			$instIdx_t = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][6]};
			@tmp_finger_t = getAvailableNumFinger($inst[$instIdx_t][2], $trackEachPRow);

			## Skip If Source/Sink TR is in the same region
			if(($instIdx_s <= $lastIdxPMOS && $instIdx_t <= $lastIdxPMOS) || ($instIdx_s > $lastIdxPMOS && $instIdx_t > $lastIdxPMOS)){
				next;
			}
			if($instIdx_s <= $lastIdxPMOS){ 
				$row_s = 0;
			}
			else{
				$row_s = $numTrackH - 3;
			}
			if($instIdx_t <= $lastIdxPMOS){ 
				$row_t = 0;
			}
			else{
				$row_t = $numTrackH - 3;
			}
			## Skip if Source/Sink Pin is not "Gate" Pin
			if($pins[$h_pinId_idx{$nets[$netIndex][3]}][7] ne "G" || $pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7] ne "G"){
				next;
			}

			my $tmp_pidx_s = $nets[$netIndex][3];
			my $tmp_pidx_t = $nets[$netIndex][5][$commodityIndex];
			$tmp_pidx_s =~ s/pin\S+_(\d+)/\1/g;
			$tmp_pidx_t =~ s/pin\S+_(\d+)/\1/g;

			for my $col (1 .. $numTrackV-1){
				my $len = length(sprintf("%b", $numTrackV))+4;
				my $tmp_str = "";
				my @tmp_var_T = ();
				my @tmp_var_F = ();
				my $cnt_var_T = 0;
				my $cnt_var_F = 0;
				if(($col % 2 == 0)){
					# Variables to Set True
					$vName = "m1r".$row_s."c".$col;
					$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
					push(@tmp_var_T, $tmp_vname);
					setVar($tmp_vname, 2);
					$cnt_var_T++;
					$vName = "m1r".$row_t."c".$col;
					$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
					push(@tmp_var_T, $tmp_vname);
					setVar($tmp_vname, 2);
					$cnt_var_T++;
					for my $row (0 .. $numTrackH-4){
						my $vName_1 = "m1r".$row."c".$col;
						my $vName_2 = "m1r".($row+1)."c".$col;
						$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName_1\_$vName_2";
						push(@tmp_var_T, $tmp_vname);
						setVar($tmp_vname, 2);
						$cnt_var_T++;
					}
					# Variables to Set False
					for my $udeIndex (0 .. $#udEdges) {
						my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
						my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
						my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
						my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
						my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
						my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
						my $len = length(sprintf("%b", $numTrackV))+4;
						if(!($fromMetal==1 && $toMetal==1 && $fromCol == $toCol && $fromCol == $col)){
							$tmp_vname = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";
							if(!exists($h_assign{$tmp_vname})){
								push(@tmp_var_F, $tmp_vname);
								setVar($tmp_vname, 2);
								$cnt_var_F++;
							}
						}
					}
					for my $vEdgeIndex (0 .. $#virtualEdges) {
						my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
						my $len = length(sprintf("%b", $numTrackV))+4;
						if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3] || $virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
							if($toCol > $col || $toCol < $col){
								$tmp_vname = "M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
								if(!exists($h_assign{$tmp_vname})){
									push(@tmp_var_F, $tmp_vname);
									setVar($tmp_vname, 2);
									$cnt_var_F++;
								}
							}
						}
					}
					if($cnt_var_T>0 || $cnt_var_F>0){
						if($col-$tmp_pidx_s>0 && $col-$tmp_pidx_t>0){
							$str.="(assert (ite";
							$str.=" (and (= x$instIdx_s (_ bv".($col-$tmp_pidx_s)." $len))";
							$str.=" (= x$instIdx_t (_ bv".($col-$tmp_pidx_t)." $len)))";
							cnt("l", 0);
							cnt("l", 0);
							$str.=" (and";
							for my $m(0 .. $#tmp_var_T){
								$str.=" (= $tmp_var_T[$m] true)";
								cnt("l", 1);
							}
							for my $m(0 .. $#tmp_var_F){
								$str.=" (= $tmp_var_F[$m] false)";
								cnt("l", 1);
							}
							$str.=") (= 1 1)))\n";
							cnt("c", 1);
						}
					}
				}
			}
		}
	}
	$str.=";Set Initial Value for overlapped S/D Pins of Each P/N FET Region in the same column\n";
	## Set Initial Value for overlapped S/D Pins of Each P/N FET Region in the same column
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			my $tmp_vname = "";
			my $vName = "";
			my $startIdx = 0;
			my $endIdx_s = 0;
			my $endIdx_t = 0;
			my $instIdx_s = 0;
			my $instIdx_t = 0;
			my @tmp_finger_s = ();
			my @tmp_finger_t = ();
			my $row_s = 0;
			my $row_t = 0;

			## Source MaxFlow Indicator
			$instIdx_s = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][3]}][6]};
			@tmp_finger_s = getAvailableNumFinger($inst[$instIdx_s][2], $trackEachPRow);
			## Sink MaxFlow Indicator
			if($nets[$netIndex][5][$commodityIndex] eq $keySON){
				next;
			}
			$instIdx_t = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][6]};
			@tmp_finger_t = getAvailableNumFinger($inst[$instIdx_t][2], $trackEachPRow);

			## Skip If Source/Sink TR is in the different region
			if(($instIdx_s <= $lastIdxPMOS && $instIdx_t > $lastIdxPMOS) || ($instIdx_s > $lastIdxPMOS && $instIdx_t <= $lastIdxPMOS)){
				next;
			}
			if($instIdx_s <= $lastIdxPMOS){ 
				$row_s = 0;
			}
			else{
				$row_s = $numTrackH - 3;
			}
			if($instIdx_t <= $lastIdxPMOS){ 
				$row_t = 0;
			}
			else{
				$row_t = $numTrackH - 3;
			}
			## Skip if Source/Sink Pin is "Gate" Pin
			if($pins[$h_pinId_idx{$nets[$netIndex][3]}][7] eq "G" || $pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7] eq "G"){
				next;
			}

			my $tmp_pidx_s = $nets[$netIndex][3];
			my $tmp_pidx_t = $nets[$netIndex][5][$commodityIndex];
			$tmp_pidx_s =~ s/pin\S+_(\d+)/\1/g;
			$tmp_pidx_t =~ s/pin\S+_(\d+)/\1/g;

			## Skip if each pin is not the left/rightmost pin
			if($tmp_pidx_s > 0 && $tmp_pidx_s < $tmp_finger_s[0]*2){
				next;
			}
			if($tmp_pidx_t > 0 && $tmp_pidx_t < $tmp_finger_t[0]*2){
				next;
			}

			for my $col (1 .. $numTrackV-1){
				my $len = length(sprintf("%b", $numTrackV))+4;
				my $tmp_str = "";
				my @tmp_var_T = ();
				my @tmp_var_F = ();
				my $cnt_var_T = 0;
				my $cnt_var_F = 0;
				if(($col % 2 == 1)){
					# Variables to Set True
					$vName = "m1r".$row_s."c".$col;
					$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
					push(@tmp_var_T, $tmp_vname);
					setVar($tmp_vname, 2);
					$cnt_var_T++;
					$vName = "m1r".$row_t."c".$col;
					$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
					push(@tmp_var_T, $tmp_vname);
					setVar($tmp_vname, 2);
					$cnt_var_T++;
					# Variables to Set False
					for my $udeIndex (0 .. $#udEdges) {
						my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
						my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
						my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
						my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
						my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
						my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
						my $len = length(sprintf("%b", $numTrackV))+4;
						$tmp_vname = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";
						if(!exists($h_assign{$tmp_vname})){
							push(@tmp_var_F, $tmp_vname);
							setVar($tmp_vname, 2);
							$cnt_var_F++;
						}
					}
					for my $vEdgeIndex (0 .. $#virtualEdges) {
						my $toRow   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[2];
						my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
						my $len = length(sprintf("%b", $numTrackV))+4;
						if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3] || $virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
							if(($toCol > $col || $toCol < $col)){
								$tmp_vname = "M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
								if(!exists($h_assign{$tmp_vname})){
									push(@tmp_var_F, $tmp_vname);
									setVar($tmp_vname, 2);
									$cnt_var_F++;
								}
							}
						}
					}
					if($cnt_var_T>0 || $cnt_var_F>0){
						$startIdx = 0;
						$endIdx_s = $tmp_finger_s[0]*2+1;
						$endIdx_t = $tmp_finger_t[0]*2+1;
						$str.="(assert (ite (and";
						my $isValid = 0;
						if($tmp_pidx_s <= $col){
							$isValid = 1;
							$str.=" (or (and (= ff$instIdx_s false)";
							cnt("l", 0);
							$str.=" (= x$instIdx_s (_ bv".($col-$tmp_pidx_s)." $len)))";
							cnt("l", 0);
						}
						if (((($startIdx + $endIdx_s - 1 - $tmp_pidx_s)%2==0?($startIdx + $endIdx_s - 1 - $tmp_pidx_s):($startIdx + $endIdx_s - 1 - $tmp_pidx_s + 1))) <= $col){
							if($isValid == 0){
								$str.=" (or (and (= ff$instIdx_s true)";
								cnt("l", 0);
								$isValid = 1;
							}
							else{
								$str.=" (and (= ff$instIdx_s true)";
								cnt("l", 0);
							}
							my $len = length(sprintf("%b", $numTrackV))+4;
							$str.=" (= x$instIdx_s (_ bv".($col-((($startIdx + $endIdx_s - 1 - $tmp_pidx_s)%2==0?($startIdx + $endIdx_s - 1 - $tmp_pidx_s):($startIdx + $endIdx_s - 1 - $tmp_pidx_s + 1))))." $len)))";
							cnt("l", 0);
						}
						if($isValid == 0){
							next;
						}
						$str.=")";
						$isValid = 0;
						if($tmp_pidx_t <= $col){
							$isValid = 1;
							$str.=" (or (and (= ff$instIdx_t false)";
							cnt("l", 0);
							$str.=" (= x$instIdx_t (_ bv".($col-$tmp_pidx_t)." $len)))";
							cnt("l", 0);
						}
						if (((($startIdx + $endIdx_t - 1 - $tmp_pidx_t)%2==0?($startIdx + $endIdx_t - 1 - $tmp_pidx_t):($startIdx + $endIdx_t - 1 - $tmp_pidx_t + 1))) <= $col){
							if($isValid == 0){
								$str.=" (or (and (= ff$instIdx_t true)";
								cnt("l", 0);
								$isValid = 1;
							}
							else{
								$str.=" (and (= ff$instIdx_t true)";
								cnt("l", 0);
							}
							my $len = length(sprintf("%b", $numTrackV))+4;
							$str.=" (= x$instIdx_t (_ bv".($col-((($startIdx + $endIdx_t - 1 - $tmp_pidx_t)%2==0?($startIdx + $endIdx_t - 1 - $tmp_pidx_t):($startIdx + $endIdx_t - 1 - $tmp_pidx_t + 1))))." $len)))";
							cnt("l", 0);
						}
						if($isValid == 0){
							next;
						}
						$str.=")";
						$str.=") (and";
						for my $m(0 .. $#tmp_var_T){
							cnt("l", 1);
						}
						for my $m(0 .. $#tmp_var_F){
							$str.=" (= $tmp_var_F[$m] false)";
							cnt("l", 1);
						}
						$str.=") (= 1 1)))\n";
						cnt("c", 1);
					}
				}
			}
		}
	}

	$str.=";Flow Capacity Control\n";
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			my $tmp_vname = "";
			my $vName = "";
			my $startIdx = 0;
			my $endIdx = 0;
			my $instIdx = 0;
			my $ru = 0;
			my $rl = 0;
			my $r_l = 0;
			my $r_u = 0;
			my $c_l = 0;
			my $c_u = 0;
			my @tmp_finger = ();

			## Source MaxFlow Indicator
			$instIdx = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][3]}][6]};
			@tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);

			if($instIdx <= $lastIdxPMOS){ 
				$ru = $h_RTrack{$numPTrackH-1-$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
				$rl = $h_RTrack{$numPTrackH-1};
				$r_l = 0;
				$r_u = $numTrackH/2-2;
				$c_l = 0;
				$c_u = $numTrackV-1;
			}
			else{
				$ru = $h_RTrack{0};
				$rl = $h_RTrack{$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
				$r_l = $numTrackH/2-1;
				$r_u = $numTrackH-3;
				$c_l = 0;
				$c_u = $numTrackV-1;
			}
			for my $col ($c_l .. $c_u){
				if($pins[$h_pinId_idx{$nets[$netIndex][3]}][7] eq "G"){ ### GATE Pin
					my $tmp_pidx = $nets[$netIndex][3];
					$tmp_pidx =~ s/pin\S+_(\d+)/\1/g;
					$startIdx = 0;
					$endIdx = 0;
					if(($col % 2 == 0)){
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 2 == 1){
									if($j==0){
										if($tmp_pidx > $col){
											for my $row ($r_l .. $r_u){
												if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
													$vName = "m1r".$row."c".$col;
													$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
													if(!exists($h_assign{$tmp_vname})){
														$h_assign_new{$tmp_vname} = 0;
													}
												}
											}
										}
										else{
											my $len = length(sprintf("%b", $numTrackV))+4;
											my $tmp_str = "";
											my @tmp_var = ();
											my $cnt_var = 0;
											my $cnt_true = 0;

											for my $row ($r_l .. $r_u){
												$vName = "m1r".$row."c".$col;
												$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
												if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
													if(!exists($h_assign{$tmp_vname})){
														push(@tmp_var, $tmp_vname);
														setVar($tmp_vname, 2);
														$cnt_var++;
													}
													elsif(exists($h_assign{$tmp_vname}) && $h_assign{$tmp_vname} == 1){
														setVar_wo_cnt($tmp_vname, 2);
														$cnt_true++;
													}
												}
											}
											if($cnt_true>1){
												print "[ERROR] at-leat 2 variables are true in the exactly 1 clause!!\n";
												exit(-1);
											}
											elsif($cnt_var>0){
												$str.="(assert (ite";
												$str.=" (= x$instIdx (_ bv".($col-$tmp_pidx)." $len))";
												cnt("l", 0);
												if($cnt_true==1){
													$str.=" (and";
													for my $m(0 .. $#tmp_var){
														$str.=" (= $tmp_var[$m] false)";
														cnt("l", 1);
													}
													$str.=") (and";
												}
												else{
													$str.=" (and ((_ at-least 1)";
													for my $m(0 .. $#tmp_var){
														$str.=" $tmp_var[$m]";
														cnt("l", 1);
													}
													$str.=") ((_ at-most 1)";
													for my $m(0 .. $#tmp_var){
														$str.=" $tmp_var[$m]";
														cnt("l", 1);
													}
													$str.=")) (and";
												}
												for my $m(0 .. $#tmp_var){
													$str.=" (= $tmp_var[$m] false)";
													cnt("l", 1);
												}
												$str.=")))\n";
												cnt("c", 1);
											}
										}
									}
									last;
								}
							}
						}
					}
				}
				elsif($pins[$h_pinId_idx{$nets[$netIndex][3]}][7] eq "S"){ ### Source Pin
					my $tmp_pidx = $nets[$netIndex][3];
					$tmp_pidx =~ s/pin\S+_(\d+)/\1/g;
					$startIdx = 0;
					$endIdx = 0;
					my $isValid = 0;
					my $tmp_str_1 = "";
					if(($col % 2 == 1)){
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 0){
									if($j==0){
										if($tmp_pidx <= $col){
											$isValid = 1;
											$tmp_str_1.="(assert (ite (or (and (= ff$instIdx false)";
											cnt("l", 0);
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-$tmp_pidx)." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						$startIdx = 0;
						$endIdx = 0;
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 0){
									if($j==0){
										if (((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))) <= $col){
											if($isValid == 0){
												$tmp_str_1.="(assert (ite (or (and (= ff$instIdx true)";
												cnt("l", 0);
												$isValid = 1;
											}
											else{
												$tmp_str_1.=" (and (= ff$instIdx true)";
												cnt("l", 0);
											}
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))))." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						if($isValid==1){
							my $tmp_str = "";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							for my $row ($r_l .. $r_u){
								$vName = "m1r".$row."c".$col;
								$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									if(!exists($h_assign{$tmp_vname})){
										push(@tmp_var, $tmp_vname);
										setVar($tmp_vname, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_vname}) && $h_assign{$tmp_vname} == 1){
										setVar_wo_cnt($tmp_vname, 2);
										$cnt_true++;
									}
								}
							}
							if($cnt_true>1){
								print "[ERROR] at-leat 2 variables are true in the exactly 1 clause!!\n";
								exit(-1);
							}
							elsif($cnt_var>0){
								$str.=$tmp_str_1;
								if($cnt_true==1){
									$str.=") (and";
									for my $m(0 .. $#tmp_var){
										$str.=" (= $tmp_var[$m] false)";
										cnt("l", 1);
									}
									$str.=") (and";
								}
								else{
									$str.=") (and ((_ at-least 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=") ((_ at-most 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=")) (and";
								}
								for my $m(0 .. $#tmp_var){
									$str.=" (= $tmp_var[$m] false)";
									cnt("l", 1);
								}
								$str.=")))\n";
								cnt("c", 1);
							}
						}
						else{
							for my $row ($r_l .. $r_u){
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									$vName = "m1r".$row."c".$col;
									$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
									if(!exists($h_assign{$tmp_vname})){
										$h_assign_new{$tmp_vname} = 0;
									}
								}
							}
						}
					}
				}
				elsif($pins[$h_pinId_idx{$nets[$netIndex][3]}][7] eq "D"){ ### Drain Pin
					### Drain Pin
					my $tmp_pidx = $nets[$netIndex][3];
					$tmp_pidx =~ s/pin\S+_(\d+)/\1/g;
					$startIdx = 0;
					$endIdx = 0;
					my $isValid = 0;
					my $tmp_str_1 = "";
					if(($col % 2 == 1)){
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 2){
									if($j==0){
										if($tmp_pidx <= $col){
											$isValid = 1;
											$tmp_str_1.="(assert (ite (or (and (= ff$instIdx false)";
											cnt("l", 0);
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-$tmp_pidx)." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						$startIdx = 0;
						$endIdx = 0;
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 2){
									if($j==0){
										if (((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))) <= $col){
											if($isValid == 0){
												$tmp_str_1.="(assert (ite (or (and (= ff$instIdx true)";
												cnt("l", 0);
												$isValid = 1;
											}
											else{
												$tmp_str_1.=" (and (= ff$instIdx true)";
												cnt("l", 0);
											}
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))))." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						if($isValid==1){
							my $tmp_str = "";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							for my $row ($r_l .. $r_u){
								$vName = "m1r".$row."c".$col;
								$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									if(!exists($h_assign{$tmp_vname})){
										push(@tmp_var, $tmp_vname);
										setVar($tmp_vname, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_vname}) && $h_assign{$tmp_vname} == 1){
										setVar_wo_cnt($tmp_vname, 2);
										$cnt_true++;
									}
								}
							}
							if($cnt_true>1){
								print "[ERROR] at-leat 2 variables are true in the exactly 1 clause!!\n";
								exit(-1);
							}
							elsif($cnt_var>0){
								$str.=$tmp_str_1;
								if($cnt_true==1){
									$str.=") (and";
									for my $m(0 .. $#tmp_var){
										$str.=" (= $tmp_var[$m] false)";
										cnt("l", 1);
									}
									$str.=") (and";
								}
								else{
									$str.=") (and ((_ at-least 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=") ((_ at-most 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=")) (and";
								}
								for my $m(0 .. $#tmp_var){
									$str.=" (= $tmp_var[$m] false)";
									cnt("l", 1);
								}
								$str.=")))\n";
								cnt("c", 1);
							}
						}
						else{
							for my $row ($r_l .. $r_u){
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									$vName = "m1r".$row."c".$col;
									$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][3]";
									if(!exists($h_assign{$tmp_vname})){
										$h_assign_new{$tmp_vname} = 0;
									}
								}
							}
						}
					}
				}
			}
			## Sink MaxFlow Indicator
			if($nets[$netIndex][5][$commodityIndex] eq $keySON){
				next;
			}
			$instIdx = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][6]};
			@tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);

			if($instIdx <= $lastIdxPMOS){ 
				$ru = $h_RTrack{$numPTrackH-1-$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
				$rl = $h_RTrack{$numPTrackH-1};
				$r_l = 0;
				$r_u = $numTrackH/2-2;
				$c_l = 0;
				$c_u = $numTrackV-1;
			}
			else{
				$ru = $h_RTrack{0};
				$rl = $h_RTrack{$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
				$r_l = $numTrackH/2-1;
				$r_u = $numTrackH-3;
				$c_l = 0;
				$c_u = $numTrackV-1;
			}
			for my $col ($c_l .. $c_u){
				if($pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7] eq "G"){ ### GATE Pin
					my $tmp_pidx = $nets[$netIndex][5][$commodityIndex];
					$tmp_pidx =~ s/pin\S+_(\d+)/\1/g;
					$startIdx = 0;
					$endIdx = 0;
					if(($col % 2 == 0)){
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 2 == 1){
									if($j==0){
										if($tmp_pidx > $col){
											for my $row ($r_l .. $r_u){
												if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
													$vName = "m1r".$row."c".$col;
													$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
													if(!exists($h_assign{$tmp_vname})){
														$h_assign_new{$tmp_vname} = 0;
													}
												}
											}
										}
										else{
											my $len = length(sprintf("%b", $numTrackV))+4;
											my $tmp_str = "";
											my @tmp_var = ();
											my $cnt_var = 0;
											my $cnt_true = 0;

											for my $row ($r_l .. $r_u){
												$vName = "m1r".$row."c".$col;
												$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
												if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
													if(!exists($h_assign{$tmp_vname})){
														push(@tmp_var, $tmp_vname);
														setVar($tmp_vname, 2);
														$cnt_var++;
													}
													elsif(exists($h_assign{$tmp_vname}) && $h_assign{$tmp_vname} == 1){
														setVar_wo_cnt($tmp_vname, 2);
														$cnt_true++;
													}
												}
											}
											if($cnt_true>1){
												print "[ERROR] at-leat 2 variables are true in the exactly 1 clause!!\n";
												exit(-1);
											}
											elsif($cnt_var>0){
												$str.="(assert (ite";
												$str.=" (= x$instIdx (_ bv".($col-$tmp_pidx)." $len))";
												cnt("l", 0);
												if($cnt_true==1){
													$str.=" (and";
													for my $m(0 .. $#tmp_var){
														$str.=" (= $tmp_var[$m] false)";
														cnt("l", 1);
													}
													$str.=") (and";
												}
												else{
													$str.=" (and ((_ at-least 1)";
													for my $m(0 .. $#tmp_var){
														$str.=" $tmp_var[$m]";
														cnt("l", 1);
													}
													$str.=") ((_ at-most 1)";
													for my $m(0 .. $#tmp_var){
														$str.=" $tmp_var[$m]";
														cnt("l", 1);
													}
													$str.=")) (and";
												}
												for my $m(0 .. $#tmp_var){
													$str.=" (= $tmp_var[$m] false)";
													cnt("l", 1);
												}
												$str.=")))\n";
												cnt("c", 1);
											}
										}
									}
									last;
								}
							}
						}
					}
				}
				elsif($pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7] eq "S"){ ### Source Pin
					my $tmp_pidx = $nets[$netIndex][5][$commodityIndex];
					$tmp_pidx =~ s/pin\S+_(\d+)/\1/g;
					$startIdx = 0;
					$endIdx = 0;
					my $isValid = 0;
					my $tmp_str_1 = "";
					if(($col % 2 == 1)){
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 0){
									if($j==0){
										if($tmp_pidx <= $col){
											$isValid = 1;
											$tmp_str_1.="(assert (ite (or (and (= ff$instIdx false)";
											cnt("l", 0);
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-$tmp_pidx)." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						$startIdx = 0;
						$endIdx = 0;
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 0){
									if($j==0){
										if (((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))) <= $col){
											if($isValid == 0){
												$tmp_str_1.="(assert (ite (or (and (= ff$instIdx true)";
												$isValid = 1;
												cnt("l", 0);
											}
											else{
												$tmp_str_1.=" (and (= ff$instIdx true)";
												cnt("l", 0);
											}
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))))." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						if($isValid==1){
							my $tmp_str = "";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							for my $row ($r_l .. $r_u){
								$vName = "m1r".$row."c".$col;
								$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									if(!exists($h_assign{$tmp_vname})){
										push(@tmp_var, $tmp_vname);
										setVar($tmp_vname, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_vname}) && $h_assign{$tmp_vname} == 1){
										setVar_wo_cnt($tmp_vname, 2);
										$cnt_true++;
									}
								}
							}
							if($cnt_true>1){
								print "[ERROR] at-leat 2 variables are true in the exactly 1 clause!!\n";
								exit(-1);
							}
							elsif($cnt_var>0){
								$str.=$tmp_str_1;
								if($cnt_true==1){
									$str.=") (and";
									for my $m(0 .. $#tmp_var){
										$str.=" (= $tmp_var[$m] false)";
										cnt("l", 1);
									}
									$str.=") (and";
								}
								else{
									$str.=") (and ((_ at-least 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=") ((_ at-most 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=")) (and";
								}
								for my $m(0 .. $#tmp_var){
									$str.=" (= $tmp_var[$m] false)";
									cnt("l", 1);
								}
								$str.=")))\n";
								cnt("c", 1);
							}
						}
						else{
							for my $row ($r_l .. $r_u){
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									$vName = "m1r".$row."c".$col;
									$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
									if(!exists($h_assign{$tmp_vname})){
										$h_assign_new{$tmp_vname} = 0;
									}
								}
							}
						}
					}
				}
				elsif($pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7] eq "D"){ ### Drain Pin
					### Drain Pin
					my $tmp_pidx = $nets[$netIndex][5][$commodityIndex];
					$tmp_pidx =~ s/pin\S+_(\d+)/\1/g;
					$startIdx = 0;
					$endIdx = 0;
					my $isValid = 0;
					my $tmp_str_1 = "";
					if(($col % 2 == 1)){
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 2){
									if($j==0){
										if($tmp_pidx <= $col){
											$isValid = 1;
											$tmp_str_1.="(assert (ite (or (and (= ff$instIdx false)";
											cnt("l", 0);
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-$tmp_pidx)." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						$startIdx = 0;
						$endIdx = 0;
						for my $j(0 .. $#tmp_finger){
							if($j>0) {
								$startIdx = $tmp_finger[$j-1]*2 + 1
							}
							$endIdx = $tmp_finger[$j]*2 + 1;
							if($tmp_pidx >= $startIdx && $tmp_pidx <= $endIdx-1){
								if($tmp_pidx % 4 == 2){
									if($j==0){
										if (((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))) <= $col){
											if($isValid == 0){
												$tmp_str_1.="(assert (ite (or (and (= ff$instIdx true)";
												cnt("l", 0);
												$isValid = 1;
											}
											else{
												$tmp_str_1.=" (and (= ff$instIdx true)";
												cnt("l", 0);
											}
											my $len = length(sprintf("%b", $numTrackV))+4;
											$tmp_str_1.=" (= x$instIdx (_ bv".($col-((($startIdx + $endIdx - 1 - $tmp_pidx)%2==0?($startIdx + $endIdx - 1 - $tmp_pidx):($startIdx + $endIdx - 1 - $tmp_pidx + 1))))." $len)))";
											cnt("l", 0);
										}
									}
									last;
								}
							}
						}
						if($isValid==1){
							my $tmp_str = "";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							for my $row ($r_l .. $r_u){
								$vName = "m1r".$row."c".$col;
								$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									if(!exists($h_assign{$tmp_vname})){
										push(@tmp_var, $tmp_vname);
										setVar($tmp_vname, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_vname}) && $h_assign{$tmp_vname} == 1){
										setVar_wo_cnt($tmp_vname, 2);
										$cnt_true++;
									}
								}
							}
							if($cnt_true>1){
								print "[ERROR] at-leat 2 variables are true in the exactly 1 clause!!\n";
								exit(-1);
							}
							elsif($cnt_var>0){
								$str.=$tmp_str_1;
								if($cnt_true==1){
									$str.=") (and";
									for my $m(0 .. $#tmp_var){
										$str.=" (= $tmp_var[$m] false)";
										cnt("l", 1);
									}
									$str.=") (and";
								}
								else{
									$str.=") (and ((_ at-least 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=") ((_ at-most 1)";
									for my $m(0 .. $#tmp_var){
										$str.=" $tmp_var[$m]";
										cnt("l", 1);
									}
									$str.=")) (and";
								}
								for my $m(0 .. $#tmp_var){
									$str.=" (= $tmp_var[$m] false)";
									cnt("l", 1);
								}
								$str.=")))\n";
								cnt("c", 1);
							}
						}
						else{
							for my $row ($r_l .. $r_u){
								if(exists($h_mapTrack{$row}) && $rl <= $row && $ru >= $row){
									$vName = "m1r".$row."c".$col;
									$tmp_vname = "N$nets[$netIndex][1]_C$commodityIndex\_E_$vName\_$nets[$netIndex][5][$commodityIndex]";
									if(!exists($h_assign{$tmp_vname})){
										$h_assign_new{$tmp_vname} = 0;
									}
								}
							}
						}
					}
				}
			}
		}
	}

	if($Local_Parameter == 1){
		$str.=";Localization.\n\n";
		$str.=";Conditional Localization for All Commodities\n\n";
		for my $netIndex (0 .. $#nets) {
			for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
				my $inst_pin_s = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][3]}][6]};
				my $inst_pin_t = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][6]};
				my $type_s = $pins[$h_pinId_idx{$nets[$netIndex][3]}][7];
				my $type_t = $pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][7];
				my $pidx_s = $nets[$netIndex][3];
				my $pidx_t = $nets[$netIndex][5][$commodityIndex];
				my @finger_s = getAvailableNumFinger($inst[$inst_pin_s][2], $trackEachPRow);
				my @finger_t = getAvailableNumFinger($inst[$inst_pin_t][2], $trackEachPRow);
				my $w_s = $finger_s[0]*2;
				my $w_t = $finger_t[0]*2;
				my $len = length(sprintf("%b", $numTrackV))+4;
				$pidx_s =~ s/pin\S+_(\d+)/\1/g;
				$pidx_t =~ s/pin\S+_(\d+)/\1/g;
				if($type_s eq "G"){
					$w_s = 2*$pidx_s;
				}
				if($type_t eq "G"){
					$w_t = 2*$pidx_t;
				}
				my %h_edge = ();
				my $tmp_str = "";

				if($nets[$netIndex][5][$commodityIndex] ne $keySON){
					for my $col (0 .. $numTrackV-1){
						$str.="(assert (ite (and (= ff$inst_pin_s false) (= ff$inst_pin_t false)) (ite (bvsge (bvadd x$inst_pin_s (_ bv$pidx_s $len)) (bvadd x$inst_pin_t (_ bv$pidx_t $len)))\n";
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						$str.="             (and (ite (bvslt x$inst_pin_s (_ bv".($col-$tolerance-$pidx_s>=0?($col-$tolerance-$pidx_s):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_t (_ bv".($col+$tolerance-$pidx_t>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$pidx_t>=0?($col+$tolerance-$pidx_t):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true)))\n";
						$str.="             (and (ite (bvslt x$inst_pin_t (_ bv".($col-$tolerance-$pidx_t>=0?($col-$tolerance-$pidx_t):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_s (_ bv".($col+$tolerance-$pidx_s>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$pidx_s>=0?($col+$tolerance-$pidx_s):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))))\n";
						$str.="	(ite (and (= ff$inst_pin_s false) (= ff$inst_pin_t true)) (ite (bvsge (bvadd x$inst_pin_s (_ bv$pidx_s $len)) (bvadd x$inst_pin_t (_ bv".($w_t-$pidx_t)." $len)))\n";
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						$str.="             (and (ite (bvslt x$inst_pin_s (_ bv".($col-$tolerance-$pidx_s>=0?($col-$tolerance-$pidx_s):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_t (_ bv".($col+$tolerance-$w_t+$pidx_t>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$w_t+$pidx_t>=0?($col+$tolerance-$w_t+$pidx_t):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true)))\n";
						$str.="             (and (ite (bvslt x$inst_pin_t (_ bv".($col-$tolerance-$w_t+$pidx_t>=0?($col-$tolerance-$w_t+$pidx_t):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_s (_ bv".($col+$tolerance-$pidx_s>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$pidx_s>=0?($col+$tolerance-$pidx_s):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))))\n";
						$str.="	(ite (and (= ff$inst_pin_s true) (= ff$inst_pin_t false)) (ite (bvsge (bvadd x$inst_pin_s (_ bv".($w_s-$pidx_s)." $len)) (bvadd x$inst_pin_t (_ bv$pidx_t $len)))\n";
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						$str.="             (and (ite (bvslt x$inst_pin_s (_ bv".($col-$tolerance-$w_s+$pidx_s>=0?($col-$tolerance-$w_s+$pidx_s):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_t (_ bv".($col+$tolerance-$pidx_t>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$pidx_t>=0?($col+$tolerance-$pidx_t):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true)))\n";
						$str.="             (and (ite (bvslt x$inst_pin_t (_ bv".($col-$tolerance-$pidx_t>=0?($col-$tolerance-$pidx_t):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_s (_ bv".($col+$tolerance-$w_s+$pidx_s>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$w_s+$pidx_s>=0?($col+$tolerance-$w_s+$pidx_s):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))))\n";
						$str.="	(ite (bvsge (bvadd x$inst_pin_s (_ bv".($w_s-$pidx_s)." $len)) (bvadd x$inst_pin_t (_ bv".($w_t-$pidx_t)." $len)))\n";
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						cnt("l", 0);
						$str.="             (and (ite (bvslt x$inst_pin_s (_ bv".($col-$tolerance-$w_s+$pidx_s>=0?($col-$tolerance-$w_s+$pidx_s):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_t (_ bv".($col+$tolerance-$w_t+$pidx_t>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$w_t+$pidx_t>=0?($col+$tolerance-$w_t+$pidx_t):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true)))\n";
						$str.="             (and (ite (bvslt x$inst_pin_t (_ bv".($col-$tolerance-$w_t+$pidx_t>=0?($col-$tolerance-$w_t+$pidx_t):(0))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))\n";
						$str.="                  (ite (bvsgt x$inst_pin_s (_ bv".($col+$tolerance-$w_s+$pidx_s>=$numTrackV-1?($numTrackV-1):($col+$tolerance-$w_s+$pidx_s>=0?($col+$tolerance-$w_s+$pidx_s):(0)))." $len)) (and"; 
						cnt("l", 0);
						%h_edge = ();
						for my $row (0 .. $numTrackH-3) {
							for my $metal (1 .. $numMetalLayer) { 
								if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
									next;
								}
								my $vName = "m".$metal."r".$row."c".$col;
								for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
									if(!exists($h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$edge_in{$vName}[$i]][1]_$vName", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
											$str.=" false)";
											$h_edge{"$udEdges[$edge_in{$vName}[$i]][1]_$vName"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
									if(!exists($h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
										if(!exists($h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]"})){
											setVar("N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]", 2);
											$str.=" (= ";
											$str.="N$nets[$netIndex][1]\_";
											$str.="C$commodityIndex\_";
											$str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
											$str.=" false)";
											$h_edge{"$vName\_$udEdges[$edge_out{$vName}[$i]][2]"} = 1;
											cnt("l", 1);
										}
									}
								}
								for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
									if(!exists($h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"})){
										if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3] || $virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
											$tmp_str ="N$nets[$netIndex][1]\_";
											$tmp_str.="C$commodityIndex\_";
											$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
											if(!exists($h_assign{$tmp_str})){
												setVar($tmp_str, 2);
												$str.=" (= ";
												$str.=$tmp_str;
												$str.=" false)";
												$h_edge{"$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]"} = 1;
												cnt("l", 1);
											}
										}
									}
								}
							}
						}
						$str.=") (= true true))))))))\n";
						cnt("c", 1);
					}
				}
			}
		}
	}
	$str.=";End of Localization\n\n";

### COMMODITY FLOW Conservation
	print "a     1. Commodity flow conservation ";
	$str.=";1. Commodity flow conservation for each vertex and every connected edge to the vertex\n";
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			for my $metal (1 .. $numMetalLayer) {   
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;
						my $tmp_str = "";
						my @tmp_var = ();
						my $cnt_var = 0;
						my $cnt_true = 0;
						for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
							$tmp_str ="N$nets[$netIndex][1]\_";
							$tmp_str.="C$commodityIndex\_";
							$tmp_str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
						}
						for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
							$tmp_str ="N$nets[$netIndex][1]\_";
							$tmp_str.="C$commodityIndex\_";
							$tmp_str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
						}
						for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
							if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3]){
								$tmp_str ="N$nets[$netIndex][1]\_";
								$tmp_str.="C$commodityIndex\_";
								$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
							}
							if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
								$tmp_str ="N$nets[$netIndex][1]\_";
								$tmp_str.="C$commodityIndex\_";
								$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
							}
						}
						if($cnt_true > 0){
							if($cnt_true>2){
								print "[ERROR] number of true commodity variable exceed 2!! in Vertex[$vName]\n";
								exit(-1);
							}
							elsif($cnt_true>1){
								# if # of true variables is two, then remained variables should be false
								if(!exists($h_assign{$tmp_var[0]})){
									$h_assign_new{$tmp_var[0]} = 0;
								}
							}
							else{
								# if # of true variables is one, then remained variable should be exactly one
								if($cnt_var == 1){
									if(!exists($h_assign{$tmp_var[0]})){
										$h_assign_new{$tmp_var[0]} = 1;
									}
									setVar_wo_cnt($tmp_var[0], 0);
								}
								elsif($cnt_var>1){
									# at-most 1
									$str.= "(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.= " $tmp_var[$i]";
										cnt("l", 1);
									}
									$str.= "))\n";
									cnt("c", 1);
									# at-least 1
									$str.= "(assert ((_ at-least 1)";
									for my $i(0 .. $#tmp_var){
										$str.= " $tmp_var[$i]";
										cnt("l", 1);
									}
									$str.= "))\n";
									cnt("c", 1);
								}
							}
						}
						# true-assigned variable is not included in terms
						else{
							# if # of rest variables is one, then that variable should be false
							if($cnt_var == 1){
								if(!exists($h_assign{$tmp_var[0]})){
									$h_assign_new{$tmp_var[0]} = 0;
								}
							}
							elsif($cnt_var == 2){
								$str.="(assert (= (or (not $tmp_var[0]) $tmp_var[1]) true))\n";
								cnt("l", 1);
								cnt("l", 1);
								cnt("c", 1);
								$str.="(assert (= (or $tmp_var[0] (not $tmp_var[1])) true))\n";
								cnt("l", 1);
								cnt("l", 1);
								cnt("c", 1);
							}
							elsif($cnt_var > 2){
								#at-most 2
								$str.= "(assert ((_ at-most 2)";
								for my $i(0 .. $#tmp_var){
									$str.= " $tmp_var[$i]";
									cnt("l", 1);
								}
								$str.= "))\n";
								cnt("c", 1);
								# not exactly-1
								for my $i(0 .. $#tmp_var){
									$str.="(assert (= (or";
									for my $j(0 .. $#tmp_var){
											if($i==$j){
												$str.=" (not $tmp_var[$j])";
											}
											else{
												$str.=" $tmp_var[$j]";
											}
											cnt("l", 1);
									}
									$str.=") true))\n";
									cnt("c", 1);
								}
							}
						}
					}
				}
			}
		}
	}
	$str.=";M4 Layer Constraints\n";
### M4 Layer's flow should be true for a pair of edge flows because only via3,4 is only feasible at the even or odd columns
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			for my $metal (4 .. $numMetalLayer) {   
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {
						if($metal % 2 == 1){
							next;
						}
						if($col % 2 == 0){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;
						my $tmp_str = "";
						my @tmp_var = ();
						my $cnt_var = 0;
						my $cnt_true = 0;
						for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
							my $fromMetal = (split /[a-z]/, $udEdges[$edge_in{$vName}[$i]][1])[1]; # 1:metal 2:row 3:col
							if($fromMetal != $metal){
								next;
							}
							$tmp_str ="N$nets[$netIndex][1]\_";
							$tmp_str.="C$commodityIndex\_";
							$tmp_str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
						}
						for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
							my $toMetal = (split /[a-z]/, $udEdges[$edge_out{$vName}[$i]][2])[1]; # 1:metal 2:row 3:col
							if($toMetal != $metal){
								next;
							}
							$tmp_str ="N$nets[$netIndex][1]\_";
							$tmp_str.="C$commodityIndex\_";
							$tmp_str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
						}
						if($cnt_true > 0){
							if($cnt_true>2){
								print "[ERROR] number of true commodity variable exceed 2!! in Vertex[$vName]\n";
								exit(-1);
							}
							else{
								# if # of true variables is one, then remained variable should be true
								if($cnt_var > 1){
									print "[ERROR] number of commodity pair exceeds 2!! in Vertex[$vName]\n";
									exit(-1);
								}
								elsif($cnt_var == 1){
									if(!exists($h_assign{$tmp_var[0]})){
										$h_assign_new{$tmp_var[0]} = 1;
									}
									setVar_wo_cnt($tmp_var[0], 0);
								}
							}
						}
						# true-assigned variable is not included in terms
						elsif($cnt_var > 0) {
							# if # of rest variables is one, then that variable should be false
							if($cnt_var != 2){
								print "[ERROR] number of commodity pair is not equal to 2!! in Vertex[$vName -> $cnt_var]\n";
								exit(-1);
							}
							else{
								$str.="(assert (= $tmp_var[0] $tmp_var[1]))\n";
								cnt("l", 1);
								cnt("l", 1);
								cnt("c", 1);
							}
						}
					}
				}
			}
		}
	}
### Net Variables for CFC
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			########### It might be redundancy, some net don't need some pins ..... ###########
			for my $pinIndex (0 .. $#pins) {
				$vName = $pins[$pinIndex][0];
				if($vName eq $nets[$netIndex][5][$commodityIndex]){
					if($vName eq $keySON){
						if($EXT_Parameter == 0){
							my $tmp_str = "";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							for my $i (0 .. $#{$vedge_in{$vName}}){ # sink
								my $metal = (split /[a-z]/, $virtualEdges[$vedge_in{$vName}[$i]][1])[1]; # 1:metal 2:row 3:col
								my $row = (split /[a-z]/, $virtualEdges[$vedge_in{$vName}[$i]][1])[2]; # 1:metal 2:row 3:col
								if($metal%2 == 1 && ($row == 0 || $row == $numTrackH-3)){
									$tmp_str ="N$nets[$netIndex][1]\_";
									$tmp_str.="C$commodityIndex\_";
									$tmp_str.="E_$virtualEdges[$vedge_in{$vName}[$i]][1]_$vName";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
								}
							}
							if($cnt_true > 0){
								if($cnt_true > 1){
									print "[ERROR] # of true pinSON in Net[$nets[$netIndex][1]] Commodity[$commodityIndex] exceeds one!!\n";
									exit(-1);
								}
								else{
									# if # of true variables is one, then remained variables should be false
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							# true-assigned variable is not included in terms
							else{
								if($cnt_var == 1){
									if(!exists($h_assign{$tmp_var[0]})){
										$h_assign_new{$tmp_var[0]} = 1;
									}
									setVar_wo_cnt($tmp_var[0], 0);
								}
								elsif($cnt_var > 0){
									#at-most 1
									$str.= "(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.= " $tmp_var[$i]";
										cnt("l", 1);
									}
									$str.= "))\n";
									cnt("c", 1);
									#at-least 1
									$str.= "(assert ((_ at-least 1)";
									for my $i(0 .. $#tmp_var){
										$str.= " $tmp_var[$i]";
										cnt("l", 1);
									}
									$str.= "))\n";
									cnt("c", 1);
								}
							}
						}
						else{
							my $tmp_str = "";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							for my $i (0 .. $#{$vedge_in{$vName}}){ # sink
								my $metal = (split /[a-z]/, $virtualEdges[$vedge_in{$vName}[$i]][1])[1]; # 1:metal 2:row 3:col
								my $row = (split /[a-z]/, $virtualEdges[$vedge_in{$vName}[$i]][1])[2]; # 1:metal 2:row 3:col
								if($metal%2 == 1){
									$tmp_str ="N$nets[$netIndex][1]\_";
									$tmp_str.="C$commodityIndex\_";
									$tmp_str.="E_$virtualEdges[$vedge_in{$vName}[$i]][1]_$vName";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
								}
							}
							if($cnt_true > 0){
								if($cnt_true > 1){
									print "[ERROR] # of true pinSON in Net[$nets[$netIndex][1]] Commodity[$commodityIndex] exceeds one!!\n";
									exit(-1);
								}
								else{
									# if # of true variables is one, then remained variables should be false
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							# true-assigned variable is not included in terms
							else{
								if($cnt_var == 1){
									if(!exists($h_assign{$tmp_var[0]})){
										$h_assign_new{$tmp_var[0]} = 1;
									}
									setVar_wo_cnt($tmp_var[0], 0);
								}
								elsif($cnt_var > 0){
									#at-most 1
									$str.= "(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.= " $tmp_var[$i]";
										cnt("l", 1);
									}
									$str.= "))\n";
									cnt("c", 1);
									#at-least 1
									$str.= "(assert ((_ at-least 1)";
									for my $i(0 .. $#tmp_var){
										$str.= " $tmp_var[$i]";
										cnt("l", 1);
									}
									$str.= "))\n";
									cnt("c", 1);
								}
							}
						}
					}
					else{
						my $r_l = 0;
						my $r_u = 0;
						my $instIdx = 0;
						## Sink MaxFlow Indicator
						$instIdx = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][5][$commodityIndex]}][6]};
						if($instIdx <= $lastIdxPMOS){ 
							$r_l = 0;
							$r_u = $numTrackH/2-2;
						}
						else{
							$r_l = $numTrackH/2-1;
							$r_u = $numTrackH-3;
						}
						for my $row ($r_l .. $r_u){
							if(exists($h_mapTrack{$row})){
								my $tmp_str = "";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;
								for my $i (0 .. $#{$vedge_in{$vName}}){ # sink
									$tmp_str ="N$nets[$netIndex][1]\_";
									$tmp_str.="C$commodityIndex\_";
									$tmp_str.="E_$virtualEdges[$vedge_in{$vName}[$i]][1]_$vName";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
								}
								if($cnt_true > 0){
									if($cnt_true > 1){
										print "[ERROR] # of true pinSON in Net[$nets[$netIndex][1]] Commodity[$commodityIndex] exceeds one!!\n";
										exit(-1);
									}
									else{
										# if # of true variables is one, then remained variables should be false
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								# true-assigned variable is not included in terms
								else{
									if($cnt_var == 1){
										if(!exists($h_assign{$tmp_var[0]})){
											$h_assign_new{$tmp_var[0]} = 1;
										}
										setVar_wo_cnt($tmp_var[0], 0);
									}
									elsif($cnt_var > 0){
										#at-most 1
										$str.= "(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.= " $tmp_var[$i]";
											cnt("l", 1);
										}
										$str.= "))\n";
										cnt("c", 1);
										#at-least 1
										$str.= "(assert ((_ at-least 1)";
										for my $i(0 .. $#tmp_var){
											$str.= " $tmp_var[$i]";
											cnt("l", 1);
										}
										$str.= "))\n";
										cnt("c", 1);
									}
								}
							}
						}
					}
				}
				if($vName eq $nets[$netIndex][3]){
					my $r_l = 0;
					my $r_u = 0;
					my $instIdx = 0;
					## Source MaxFlow Indicator
					$instIdx = $h_inst_idx{$pins[$h_pinId_idx{$nets[$netIndex][3]}][6]};
					if($instIdx <= $lastIdxPMOS){ 
						$r_l = 0;
						$r_u = $numTrackH/2-2;
					}
					else{
						$r_l = $numTrackH/2-1;
						$r_u = $numTrackH-3;
					}
					my $tmp_str = "";
					my @tmp_var = ();
					my $cnt_var = 0;
					my $cnt_true = 0;
					for my $i (0 .. $#{$vedge_in{$vName}}){ # sink
						$tmp_str ="N$nets[$netIndex][1]\_";
						$tmp_str.="C$commodityIndex\_";
						$tmp_str.="E_$virtualEdges[$vedge_in{$vName}[$i]][1]_$vName";
						if(!exists($h_assign{$tmp_str})){
							push(@tmp_var, $tmp_str);
							setVar($tmp_str, 2);
							$cnt_var++;
						}
						elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
							setVar_wo_cnt($tmp_str, 0);
							$cnt_true++;
						}
					}
					if($cnt_true > 0){
						if($cnt_true > 1){
							print "[ERROR] # of true pinSON in Net[$nets[$netIndex][1]] Commodity[$commodityIndex] exceeds one!!\n";
							exit(-1);
						}
						else{
							# if # of true variables is one, then remained variables should be false
							for my $i(0 .. $#tmp_var){
								if(!exists($h_assign{$tmp_var[$i]})){
									$h_assign_new{$tmp_var[$i]} = 0;
								}
							}
						}
					}
					# true-assigned variable is not included in terms
					else{
						if($cnt_var == 1){
							if(!exists($h_assign{$tmp_var[0]})){
								$h_assign_new{$tmp_var[0]} = 1;
							}
							setVar_wo_cnt($tmp_var[0], 0);
						}
						elsif($cnt_var > 0){
							#at-most 1
							$str.= "(assert ((_ at-most 1)";
							for my $i(0 .. $#tmp_var){
								$str.= " $tmp_var[$i]";
								cnt("l", 1);
							}
							$str.= "))\n";
							cnt("c", 1);
							#at-least 1
							$str.= "(assert ((_ at-least 1)";
							for my $i(0 .. $#tmp_var){
								$str.= " $tmp_var[$i]";
								cnt("l", 1);
							}
							$str.= "))\n";
							cnt("c", 1);
						}
					}
				}
			}
		}
	}
	my $tmp_str = "";
	my @tmp_var = ();
	my $cnt_var = 0;
	my $cnt_true = 0;
	for my $netIndex (0 .. $#nets) {
		for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
			for my $metal (1 .. $numMetalLayer) {   
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;
						for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
							if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex] &&
								$virtualEdges[$vedge_out{$vName}[$i]][2] eq $keySON){
								$tmp_str ="N$nets[$netIndex][1]\_";
								$tmp_str.="C$commodityIndex\_";
								$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
							}
						}
					}
				}
			}
		}
	}
	if($cnt_true > 0){
		if($cnt_true > $numOuterPins){
			print "[ERROR] # of true pinSON exceeds $numOuterPins!!\n";
			exit(-1);
		}
		elsif($cnt_true == $numOuterPins){
			# if # of true variables is the same as # of outerpins, then remained variables should be false
			for my $i(0 .. $#tmp_var){
				if(!exists($h_assign{$tmp_var[$i]})){
					$h_assign_new{$tmp_var[$i]} = 0;
				}
			}
		}
		else{
			# at-most $numOuterPins-$cnt_true
			$str.= "(assert ((_ at-most ".($numOuterPins-$cnt_true).")";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
			# at-least $numOuterPins-$cnt_true
			$str.= "(assert ((_ at-least ".($numOuterPins-$cnt_true).")";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
		}
	}
	# true-assigned variable is not included in terms
	else{
		if($cnt_var > 0){
			#at-most numOuterPins
			$str.="(assert ((_ at-most $numOuterPins)";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
			#at-least numOuterPins
			$str.="(assert ((_ at-least $numOuterPins)";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
		}
	}
	print "has been written.\n";

### Exclusiveness use of VERTEX.  (Only considers incoming flows by nature.)
	print "a     2. Exclusiveness use of vertex ";
	$str.=";2. Exclusiveness use of vertex for each vertex and every connected edge to the vertex\n";
	for my $metal (1 .. $numMetalLayer) {   
		for my $row (0 .. $numTrackH-3) {
			for my $col (0 .. $numTrackV-1) {
				if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
					next;
				}
				$vName = "m".$metal."r".$row."c".$col;
				my $cnt_true_net = 0;
				my @tmp_var_net = ();
				my $cnt_var_net = 0;
				for my $netIndex (0 .. $#nets) {
					my $tmp_str = "";
					my @tmp_var = ();
					my $cnt_var = 0;
					my $cnt_true = 0;
					for my $i (0 .. $#{$edge_in{$vName}}){ # incoming
						$tmp_str ="N$nets[$netIndex][1]\_";
						$tmp_str.="E_$udEdges[$edge_in{$vName}[$i]][1]_$vName";
						if(!exists($h_assign{$tmp_str})){
							push(@tmp_var, $tmp_str);
							setVar($tmp_str, 2);
							$cnt_var++;
						}
						elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
							setVar_wo_cnt($tmp_str, 0);
							$cnt_true++;
						}
					}
					for my $i (0 .. $#{$edge_out{$vName}}){ # incoming
						$tmp_str ="N$nets[$netIndex][1]\_";
						$tmp_str.="E_$vName\_$udEdges[$edge_out{$vName}[$i]][2]";
						if(!exists($h_assign{$tmp_str})){
							push(@tmp_var, $tmp_str);
							setVar($tmp_str, 2);
							$cnt_var++;
						}
						elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
							setVar_wo_cnt($tmp_str, 0);
							$cnt_true++;
						}
					}
					for my $i (0 .. $#{$vedge_out{$vName}}){ # incoming
						if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3]){
							$tmp_str ="N$nets[$netIndex][1]\_";
							$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
						}
						for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
							if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex]){
								$tmp_str ="N$nets[$netIndex][1]\_";
								$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
							}
						}
					}
					my $tmp_enc = "C_N$nets[$netIndex][1]\_$vName";
					if($cnt_true>0){
						setVar_wo_cnt($tmp_enc, 0);
						$cnt_true_net++;		
					}
					elsif($cnt_var>0){
						setVar($tmp_enc, 3);
						push(@tmp_var_net, $tmp_enc);
						$cnt_var_net++;

						$str.="(assert (= $tmp_enc (or";
						cnt("l", 1);
						for my $i(0 .. $#tmp_var){
							$str.=" $tmp_var[$i]";
							cnt("l", 1);
						}
						$str.=")))\n";
						cnt("c", 1);
					}
				}
				if($cnt_true_net>1){
					print "[ERROR] There exsits more than 2 nets sharing same vertex[$vName]\n";
					exit(-1);
				}
				elsif($cnt_true_net==1){
					# remained net encode variables shoule be false
					for my $i(0 .. $#tmp_var_net){
						if(!exists($h_assign{$tmp_var_net[$i]})){
							$h_assign_new{$tmp_var_net[$i]} = 0;
						}
					}
				}
				elsif($cnt_var_net>0){
					# at-most 1
					$str.= "(assert ((_ at-most 1)";
					for my $i(0 .. $#tmp_var_net){
						$str.= " $tmp_var_net[$i]";
						cnt("l", 1);
					}
					$str.= "))\n";
					cnt("c", 1);
				}	
			}
		}
	}
	for my $netIndex (0 .. $#nets) {
		my $tmp_str = "";
		my @tmp_var = ();
		my $cnt_var = 0;
		my $cnt_true = 0;
		for my $metal (1 .. $numMetalLayer) {   
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;
					for my $i (0 .. $#{$vedge_out{$vName}}){ # incoming
						if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][3]){
							$tmp_str ="N$nets[$netIndex][1]\_";
							$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
						}
					}
				}
			}
		}
		if($cnt_true > 0){
			if($cnt_true > 1){
				print "[ERROR] # of true pin in Net[$nets[$netIndex][1]] exceeds one!!\n";
				exit(-1);
			}
			else{
				# if # of true variables is one, then remained variables should be false
				for my $i(0 .. $#tmp_var){
					if(!exists($h_assign{$tmp_var[$i]})){
						$h_assign_new{$tmp_var[$i]} = 0;
					}
				}
			}
		}
		# true-assigned variable is not included in terms
		else{
			if($cnt_var == 1){
				if(!exists($h_assign{$tmp_var[0]})){
					$h_assign_new{$tmp_var[0]} = 1;
				}
				setVar_wo_cnt($tmp_var[0], 0);
			}
			elsif($cnt_var > 0){
				#at-most 1
				$str.= "(assert ((_ at-most 1)";
				for my $i(0 .. $#tmp_var){
					$str.= " $tmp_var[$i]";
					cnt("l", 1);
				}
				$str.= "))\n";
				cnt("c", 1);
				#at-least 1
				$str.= "(assert ((_ at-least 1)";
				for my $i(0 .. $#tmp_var){
					$str.= " $tmp_var[$i]";
					cnt("l", 1);
				}
				$str.= "))\n";
				cnt("c", 1);
			}
		}
	}
	$tmp_str = "";
	@tmp_var = ();
	$cnt_var = 0;
	$cnt_true = 0;
	for my $netIndex (0 .. $#nets) {
		for my $metal (1 .. $numMetalLayer) {   
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;
					for my $i (0 .. $#{$vedge_out{$vName}}){ # incoming
						for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
							if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex] &&
								$virtualEdges[$vedge_out{$vName}[$i]][2] eq $keySON){
								$tmp_str ="N$nets[$netIndex][1]\_";
								$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
							}
						}
					}
				}
			}
		}
	}
	if($cnt_true > 0){
		if($cnt_true > $numOuterPins){
			print "[ERROR] # of true pinSON exceeds $numOuterPins!!\n";
			exit(-1);
		}
		elsif($cnt_true == $numOuterPins){
			# if # of true variables is the same as # of outerpins, then remained variables should be false
			for my $i(0 .. $#tmp_var){
				if(!exists($h_assign{$tmp_var[$i]})){
					$h_assign_new{$tmp_var[$i]} = 0;
				}
			}
		}
		else{
			# at-most $numOuterPins-$cnt_true
			$str.= "(assert ((_ at-most ".($numOuterPins-$cnt_true).")";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
			# at-least $numOuterPins-$cnt_true
			$str.= "(assert ((_ at-least ".($numOuterPins-$cnt_true).")";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
		}
	}
	# true-assigned variable is not included in terms
	else{
		if($cnt_var > 0){
			#at-most numOuterPins
			$str.="(assert ((_ at-most $numOuterPins)";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
			#at-least numOuterPins
			$str.="(assert ((_ at-least $numOuterPins)";
			for my $i(0 .. $#tmp_var){
				$str.= " $tmp_var[$i]";
				cnt("l", 1);
			}
			$str.= "))\n";
			cnt("c", 1);
		}
	}
	print "has been written.\n";


### EDGE assignment  (Assign edges based on commodity information.)
	print "a     3. Edge assignment ";
	$str.=";3. Edge assignment for each edge for every net\n";
	for my $netIndex (0 .. $#nets) {
		for my $udeIndex (0 .. $#udEdges) {
			for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
				my $tmp_com = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";
				my $tmp_net = "N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";

				if(!exists($h_assign{$tmp_com}) && !exists($h_assign{$tmp_net})){
					setVar($tmp_com, 2);
					setVar($tmp_net, 2);
					$str.="(assert (ite (= $tmp_com true) (= $tmp_net true) (= 1 1)))\n";
					cnt("l", 1);
					cnt("l", 1);
					cnt("c", 1);
				}
				elsif(exists($h_assign{$tmp_com}) && $h_assign{$tmp_com} == 1){
					if(!exists($h_assign{$tmp_net})){
						$h_assign_new{$tmp_net} = 1;
					}
					setVar_wo_cnt($tmp_net, 2);
				}
			}
		}

		for my $vEdgeIndex (0 .. $#virtualEdges) {
			my $isInNet = 0;
			if ($virtualEdges[$vEdgeIndex][2] =~ /^pin/) { # source
				if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
					$isInNet = 1;
				}
				if($isInNet == 1){
					for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
						my $tmp_com = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
						my $tmp_net = "N$nets[$netIndex][1]\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";

						if(!exists($h_assign{$tmp_com}) && !exists($h_assign{$tmp_net})){
							setVar($tmp_com, 2);
							setVar($tmp_net, 2);
							$str.="(assert (ite (= $tmp_com true) (= $tmp_net true) (= 1 1)))\n";
							cnt("l", 1);
							cnt("l", 1);
							cnt("c", 1);
						}
						elsif(exists($h_assign{$tmp_com}) && $h_assign{$tmp_com} == 1){
							if(!exists($h_assign{$tmp_net})){
								$h_assign_new{$tmp_net} = 1;
							}
							setVar_wo_cnt($tmp_net, 2);
						}
					}
				}
				$isInNet = 0;
				for my $i (0 .. $nets[$netIndex][4]-1){
					if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$i]){
						$isInNet = 1;
					}
				}
				if($isInNet == 1){
					for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
						if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
							my $tmp_com = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
							my $tmp_net = "N$nets[$netIndex][1]\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";

							if(!exists($h_assign{$tmp_com}) && !exists($h_assign{$tmp_net})){
								setVar($tmp_com, 2);
								setVar($tmp_net, 2);
								$str.="(assert (ite (= $tmp_com true) (= $tmp_net true) (= 1 1)))\n";
								cnt("l", 1);
								cnt("l", 1);
								cnt("c", 1);
							}
							elsif(exists($h_assign{$tmp_com}) && $h_assign{$tmp_com} == 1){
								if(!exists($h_assign{$tmp_net})){
									$h_assign_new{$tmp_net} = 1;
								}
								setVar_wo_cnt($tmp_net, 2);
							}
						}
					}
				}
			}
		}
	}
	print "has been written.\n";
	$str.="\n";

### Exclusiveness use of EDGES + Metal segment assignment by using edge usage information
	print "a     4. Exclusiveness use of edge ";
	$str.=";4. Exclusiveness use of each edge + Metal segment assignment by using edge usage information\n";
	for my $udeIndex (0 .. $#udEdges) {
		my $tmp_str="";
		my @tmp_var = ();
		my $cnt_var = 0;
		my $cnt_true = 0;
		for my $netIndex (0 .. $#nets) {
			$tmp_str ="N$nets[$netIndex][1]\_";
			$tmp_str.="E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";
			if(!exists($h_assign{$tmp_str})){
				push(@tmp_var, $tmp_str);
				setVar($tmp_str, 2);
				$cnt_var++;
			}
			elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
				setVar_wo_cnt($tmp_str, 0);
				$cnt_true++;
			}
		}
		my $tmp_str_metal = "M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";
		if($cnt_true>0){
			if(!exists($h_assign{$tmp_str_metal})){
				$h_assign_new{$tmp_str_metal} = 1;
			}
			setVar_wo_cnt($tmp_str_metal, 0);
		}
		elsif($cnt_var>0){
			if(exists($h_assign{$tmp_str_metal}) && $h_assign{$tmp_str_metal} == 0){
				for my $i(0 .. $#tmp_var){
					if(!exists($h_assign{$tmp_var[$i]})){
						$h_assign_new{$tmp_var[$i]} = 0;
					}
				}
			}
			else{
				setVar($tmp_str_metal, 2);
				# OR
				$str.="(assert (= $tmp_str_metal (or";
				cnt("l", 1);
				for my $i(0 .. $#tmp_var){
					$str.=" $tmp_var[$i]";
					cnt("l", 1);
				}
				$str.=")))\n";
				cnt("c", 1);
				# at-most 1
				$str.="(assert ((_ at-most 1)";
				for my $i(0 .. $#tmp_var){
					$str.=" $tmp_var[$i]";
					cnt("l", 1);
				}
				$str.="))\n";
				cnt("c", 1);
			}
		}
	}
	for my $vEdgeIndex (0 .. $#virtualEdges) {
		my $tmp_str="";
		my @tmp_var = ();
		my $cnt_var = 0;
		my $cnt_true = 0;
		for my $netIndex (0 .. $#nets) {
			my $isInNet = 0;
			if ($virtualEdges[$vEdgeIndex][2] =~ /^pin/) { # source
				if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
					$isInNet = 1;
				}
				if($isInNet == 1){
					$tmp_str ="N$nets[$netIndex][1]\_";
					$tmp_str.="E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
					if(!exists($h_assign{$tmp_str})){
						push(@tmp_var, $tmp_str);
						setVar($tmp_str, 2);
						$cnt_var++;
					}
					elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
						setVar_wo_cnt($tmp_str, 0);
						$cnt_true++;
					}
				}
				$isInNet = 0;
				for my $i (0 .. $nets[$netIndex][4]-1){
					if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$i]){
						$isInNet = 1;
					}
				}
				if($isInNet == 1){
					$tmp_str ="N$nets[$netIndex][1]\_";
					$tmp_str.="E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
					if(!exists($h_assign{$tmp_str})){
						push(@tmp_var, $tmp_str);
						setVar($tmp_str, 2);
						$cnt_var++;
					}
					elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
						setVar_wo_cnt($tmp_str, 0);
						$cnt_true++;
					}
				}
			}
		}
		my $tmp_str_metal = "M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
		if($cnt_true>0){
			if(!exists($h_assign{$tmp_str_metal})){
				$h_assign_new{$tmp_str_metal} = 1;
			}
			setVar_wo_cnt($tmp_str_metal, 0);
		}
		elsif($cnt_var>0){
			if(exists($h_assign{$tmp_str_metal}) && $h_assign{$tmp_str_metal} == 0){
				for my $i(0 .. $#tmp_var){
					if(!exists($h_assign{$tmp_var[$i]})){
						$h_assign_new{$tmp_var[$i]} = 0;
					}
				}
			}
			elsif($cnt_var==1){
				setVar($tmp_str_metal, 2);
				$str.="(assert (= $tmp_var[0] $tmp_str_metal))\n";
				cnt("l", 1);
				cnt("l", 1);
				cnt("c", 1);
			}
			else{
				setVar($tmp_str_metal, 2);
				# OR
				$str.="(assert (= $tmp_str_metal (or";
				cnt("l", 1);
				for my $i(0 .. $#tmp_var){
					$str.=" $tmp_var[$i]";
					cnt("l", 1);
				}
				$str.=")))\n";
				cnt("c", 1);
				# at-most 1
				$str.="(assert ((_ at-most 1)";
				for my $i(0 .. $#tmp_var){
					$str.=" $tmp_var[$i]";
					cnt("l", 1);
				}
				$str.="))\n";
				cnt("c", 1);
			}
		}
	}
	print "has been written.\n";

### Geometry variables for LEFT, RIGHT, FRONT, BACK directions
	print "a     6. Geometric variables ";
	$str.=";6. Geometry variables for Left (GL), Right (GR), Front (GF), and Back (GB) directions\n";
### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
	$str.=";6-A. Geometry variables for Left-tip on each vertex\n";
	for my $metal (2 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
		if ($metal % 2 == 1) {
			next;
		}
		else {
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;

					my $tmp_g = "GL_V_$vName";
					my $tmp_m1 = "M";
					if ($vertices{$vName}[5][0] ne "null") {
						$tmp_m1.="_$vertices{$vName}[5][0]_$vName";
					}
					elsif ($vertices{$vName}[5][0] eq "null") {
						$tmp_m1.="_LeftEnd_$vName";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m1})){
						setVar($tmp_g, 6);
						setVar($tmp_m1, 2);
						$str.="(assert ((_ at-most 1) $tmp_g $tmp_m1))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_m1}) && $h_assign{$tmp_m1}==1){
						if(!exists($h_assign{$tmp_g})){
							$h_assign{$tmp_g} = 0;
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m1})){
							$h_assign{$tmp_m1} = 0;
						}
					}

					my $tmp_m2 = "M";
					if ($vertices{$vName}[5][1] ne "null") {
						$tmp_m2.="_$vName\_$vertices{$vName}[5][1]";
					}
					elsif ($vertices{$vName}[5][1] eq "null") {
						$tmp_m2.="_$vName\_RightEnd";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m2})){
						setVar($tmp_g, 6);
						setVar($tmp_m2, 2);
						$str.="(assert (ite (= $tmp_g true) (= $tmp_m2 true) (= true true)))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m2})){
							$h_assign{$tmp_m2} = 1;
							setVar_wo_cnt($tmp_m2, 1);
						}
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m1})){
						if(!exists($h_assign{$tmp_m2})){
							setVar($tmp_g, 6);
							setVar($tmp_m1, 2);
							setVar($tmp_m2, 2);
							$str.="(assert (ite (= (or $tmp_g $tmp_m1) false) (= $tmp_m2 false) (= true true)))\n";
							cnt("l", 3);
							cnt("l", 3);
							cnt("l", 3);
							cnt("c", 3);
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
						if(exists($h_assign{$tmp_m1}) && $h_assign{$tmp_m1} == 0){
							if(!exists($h_assign{$tmp_m2})){
								$h_assign{$tmp_m2} = 1;
								setVar_wo_cnt($tmp_m2, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_m1})){
							if(!exists($h_assign{$tmp_m2})){
								setVar($tmp_m1, 2);
								setVar($tmp_m2, 2);
								$str.="(assert (ite (= $tmp_m1 false) (= $tmp_m2 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
					elsif(exists($h_assign{$tmp_m1}) && $h_assign{$tmp_m1} == 0){
						if(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
							if(!exists($h_assign{$tmp_g})){
								$h_assign{$tmp_g} = 1;
								setVar_wo_cnt($tmp_g, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_g})){
							if(!exists($h_assign{$tmp_m2})){
								setVar($tmp_g, 2);
								setVar($tmp_m2, 2);
								$str.="(assert (ite (= $tmp_g false) (= $tmp_m2 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
				} 
			}
		}
	}
	$str.="\n";

### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
	$str.=";6-B. Geometry variables for Right-tip on each vertex\n";
	for my $metal (2 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
		if ($metal % 2 == 1) {
			next;
		}
		else {
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;

					my $tmp_g = "GR_V_$vName";
					my $tmp_m1 = "M";
					if ($vertices{$vName}[5][0] ne "null") {
						$tmp_m1.="_$vertices{$vName}[5][0]_$vName";
					}
					elsif ($vertices{$vName}[5][0] eq "null") {
						$tmp_m1.="_LeftEnd_$vName";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m1})){
						setVar($tmp_g, 6);
						setVar($tmp_m1, 2);
						$str.="(assert (ite (= $tmp_g true) (= $tmp_m1 true) (= true true)))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m1})){
							$h_assign{$tmp_m1} = 1;
							setVar_wo_cnt($tmp_m1, 1);
						}
					}

					my $tmp_m2 = "M";
					if ($vertices{$vName}[5][1] ne "null") {
						$tmp_m2.="_$vName\_$vertices{$vName}[5][1]";
					}
					elsif ($vertices{$vName}[5][1] eq "null") {
						$tmp_m2.="_$vName\_RightEnd";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m2})){
						setVar($tmp_g, 6);
						setVar($tmp_m2, 2);
						$str.="(assert ((_ at-most 1) $tmp_g $tmp_m2))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_m2}) && $h_assign{$tmp_m2}==1){
						if(!exists($h_assign{$tmp_g})){
							$h_assign{$tmp_g} = 0;
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m2})){
							$h_assign{$tmp_m2} = 0;
						}
					}

					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m2})){
						if(!exists($h_assign{$tmp_m1})){
							setVar($tmp_g, 6);
							setVar($tmp_m2, 2);
							setVar($tmp_m1, 2);
							$str.="(assert (ite (= (or $tmp_g $tmp_m2) false) (= $tmp_m1 false) (= true true)))\n";
							cnt("l", 3);
							cnt("l", 3);
							cnt("l", 3);
							cnt("c", 3);
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
						if(exists($h_assign{$tmp_m2}) && $h_assign{$tmp_m2} == 0){
							if(!exists($h_assign{$tmp_m1})){
								$h_assign{$tmp_m1} = 1;
								setVar_wo_cnt($tmp_m1, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_m2})){
							if(!exists($h_assign{$tmp_m1})){
								setVar($tmp_m2, 2);
								setVar($tmp_m1, 2);
								$str.="(assert (ite (= $tmp_m2 false) (= $tmp_m1 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
					elsif(exists($h_assign{$tmp_m2}) && $h_assign{$tmp_m2} == 0){
						if(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
							if(!exists($h_assign{$tmp_g})){
								$h_assign{$tmp_g} = 1;
								setVar_wo_cnt($tmp_g, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_g})){
							if(!exists($h_assign{$tmp_m1})){
								setVar($tmp_g, 2);
								setVar($tmp_m1, 2);
								$str.="(assert (ite (= $tmp_g false) (= $tmp_m1 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
				}
			}
		}
	}
	$str.="\n";
### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
	$str.=";6-C. Geometry variables for Front-tip on each vertex\n";
	for my $metal (1 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
		if ($metal % 2 == 1) {
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal==1 && $col % 2 == 1){
						next;
					}
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;
					my $tmp_g = "GF_V_$vName";
					my $tmp_m1 = "M";
					if ($vertices{$vName}[5][2] ne "null") {
						$tmp_m1.="_$vertices{$vName}[5][2]_$vName";
					}
					elsif ($vertices{$vName}[5][2] eq "null") {
						$tmp_m1.="_FrontEnd_$vName";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m1})){
						setVar($tmp_g, 6);
						setVar($tmp_m1, 2);
						$str.="(assert ((_ at-most 1) $tmp_g $tmp_m1))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_m1}) && $h_assign{$tmp_m1}==1){
						if(!exists($h_assign{$tmp_g})){
							$h_assign{$tmp_g} = 0;
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m1})){
							$h_assign{$tmp_m1} = 0;
						}
					}

					my $tmp_m2 = "M";
					if ($vertices{$vName}[5][3] ne "null") {
						$tmp_m2.="_$vName\_$vertices{$vName}[5][3]";
					}
					elsif ($vertices{$vName}[5][3] eq "null") {
						$tmp_m2.="_$vName\_BackEnd";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m2})){
						setVar($tmp_g, 6);
						setVar($tmp_m2, 2);
						$str.="(assert (ite (= $tmp_g true) (= $tmp_m2 true) (= true true)))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m2})){
							$h_assign{$tmp_m2} = 1;
							setVar_wo_cnt($tmp_m2, 1);
						}
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m1})){
						if(!exists($h_assign{$tmp_m2})){
							setVar($tmp_g, 6);
							setVar($tmp_m1, 2);
							setVar($tmp_m2, 2);
							$str.="(assert (ite (= (or $tmp_g $tmp_m1) false) (= $tmp_m2 false) (= true true)))\n";
							cnt("l", 3);
							cnt("l", 3);
							cnt("l", 3);
							cnt("c", 3);
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
						if(exists($h_assign{$tmp_m1}) && $h_assign{$tmp_m1} == 0){
							if(!exists($h_assign{$tmp_m2})){
								$h_assign{$tmp_m2} = 1;
								setVar_wo_cnt($tmp_m2, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_m1})){
							if(!exists($h_assign{$tmp_m2})){
								setVar($tmp_m1, 2);
								setVar($tmp_m2, 2);
								$str.="(assert (ite (= $tmp_m1 false) (= $tmp_m2 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
					elsif(exists($h_assign{$tmp_m1}) && $h_assign{$tmp_m1} == 0){
						if(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
							if(!exists($h_assign{$tmp_g})){
								$h_assign{$tmp_g} = 1;
								setVar_wo_cnt($tmp_g, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_g})){
							if(!exists($h_assign{$tmp_m2})){
								setVar($tmp_g, 2);
								setVar($tmp_m2, 2);
								$str.="(assert (ite (= $tmp_g false) (= $tmp_m2 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
				}
			}
		}
		else {
			next;
		}
	}
	$str.="\n";
### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
	$str.=";6-D. Geometry variables for Back-tip on each vertex\n";
	for my $metal (1 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
		if ($metal % 2 == 1) {
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal==1 && $col % 2 == 1){
						next;
					}
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;

					my $tmp_g = "GB_V_$vName";
					my $tmp_m1 = "M";
					if ($vertices{$vName}[5][2] ne "null") {
						$tmp_m1.="_$vertices{$vName}[5][2]_$vName";
					}
					elsif ($vertices{$vName}[5][2] eq "null") {
						$tmp_m1.="_FrontEnd_$vName";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m1})){
						setVar($tmp_g, 6);
						setVar($tmp_m1, 2);
						$str.="(assert (ite (= $tmp_g true) (= $tmp_m1 true) (= true true)))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m1})){
							$h_assign{$tmp_m1} = 1;
							setVar_wo_cnt($tmp_m1, 1);
						}
					}

					my $tmp_m2 = "M";
					if ($vertices{$vName}[5][3] ne "null") {
						$tmp_m2.="_$vName\_$vertices{$vName}[5][3]";
					}
					elsif ($vertices{$vName}[5][3] eq "null") {
						$tmp_m2.="_$vName\_BackEnd";
					}
					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m2})){
						setVar($tmp_g, 6);
						setVar($tmp_m2, 2);
						$str.="(assert ((_ at-most 1) $tmp_g $tmp_m2))\n";
						cnt("l", 3);
						cnt("l", 3);
						cnt("c", 3);
					}
					elsif(exists($h_assign{$tmp_m2}) && $h_assign{$tmp_m2}==1){
						if(!exists($h_assign{$tmp_g})){
							$h_assign{$tmp_g} = 0;
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g}==1){
						if(!exists($h_assign{$tmp_m2})){
							$h_assign{$tmp_m2} = 0;
						}
					}

					if(!exists($h_assign{$tmp_g}) && !exists($h_assign{$tmp_m2})){
						if(!exists($h_assign{$tmp_m1})){
							setVar($tmp_g, 6);
							setVar($tmp_m2, 2);
							setVar($tmp_m1, 2);
							$str.="(assert (ite (= (or $tmp_g $tmp_m2) false) (= $tmp_m1 false) (= true true)))\n";
							cnt("l", 3);
							cnt("l", 3);
							cnt("l", 3);
							cnt("c", 3);
						}
					}
					elsif(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
						if(exists($h_assign{$tmp_m2}) && $h_assign{$tmp_m2} == 0){
							if(!exists($h_assign{$tmp_m1})){
								$h_assign{$tmp_m1} = 1;
								setVar_wo_cnt($tmp_m1, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_m2})){
							if(!exists($h_assign{$tmp_m1})){
								setVar($tmp_m2, 2);
								setVar($tmp_m1, 2);
								$str.="(assert (ite (= $tmp_m2 false) (= $tmp_m1 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
					elsif(exists($h_assign{$tmp_m2}) && $h_assign{$tmp_m2} == 0){
						if(exists($h_assign{$tmp_g}) && $h_assign{$tmp_g} == 0){
							if(!exists($h_assign{$tmp_g})){
								$h_assign{$tmp_g} = 1;
								setVar_wo_cnt($tmp_g, 1);
							}
						}
						elsif(!exists($h_assign{$tmp_g})){
							if(!exists($h_assign{$tmp_m1})){
								setVar($tmp_g, 2);
								setVar($tmp_m1, 2);
								$str.="(assert (ite (= $tmp_g false) (= $tmp_m1 false) (= true true)))\n";
								cnt("l", 3);
								cnt("l", 3);
								cnt("c", 3);
							}
						}
					}
				}
			}
		}
		else {
			next;
		}
	}
	$str.="\n";
	print "have been written.\n";

	print "a     7. Minimum area rule ";
	$str.=";7. Minimum Area Rule\n";

	if ( $MAR_Parameter == 0 ){
		print "is disable\n";
		$str.=";MAR is disable\n";
	}
	else{  # PRL Rule Enable /Disable

### Minimum Area Rule to prevent from having small metal segment
		 for my $metal (2 .. $numMetalLayer) { # no DR on M1 
			if ($metal % 2 == 0) {  # M2/M4
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV - $MAR_Parameter) {
						my $tmp_str="";
						my @tmp_var = ();
						my $cnt_var = 0;
						my $cnt_true = 0;
						for my $marIndex (0 .. $MAR_Parameter-1){
							my $colNumber = $col + $marIndex;
							my $varName = "m".$metal."r".$row."c".$colNumber;
							$tmp_str="GL_V_$varName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							$tmp_str="GR_V_$varName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
						}
						if($cnt_true>0){
							if($cnt_true>1){
								print "[ERROR] MAR : more than one G Variables are true!!!\n";
								exit(-1);
							}
							else{
								for my $i(0 .. $#tmp_var){
									if(!exists($h_assign{$tmp_var[$i]})){
										$h_assign_new{$tmp_var[$i]} = 0;
									}
								}
							}
						}
						else{
							if($cnt_var > 1){
								$str.="(assert ((_ at-most 1)";
								for my $i(0 .. $#tmp_var){
									$str.=" $tmp_var[$i]";
									cnt("l", 3);
								}
								$str.="))\n";
								cnt("c", 3);
							}
						}
					}
				}
			}
			else {  # M1, M3
				my $MaxIndex = $MAR_Parameter-1;
				if ($DoublePowerRail == 1){
					$MaxIndex--;
				}
							
				for my $row (0 .. $numTrackH - 3 - $MaxIndex) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}

						#### [2019-01-07] Flexible Parameter considering Double Power Rail ####
						my $powerRailFlag = 0; my $powerRailIndex = 0; 
						my $varName = "m".$metal."r".$row."c".$col;
						my $newRow = $row;

						if( ($vertices{$varName}[5][3] eq "null") || (( $DoublePowerRail == 1) && (($newRow + 1) % ($trackEachRow + 1) == 0) && ($MAR_Parameter == 2)) ){
							next;  # Skip to generate the constraint for this condition.
						}
				
						my $tmp_str="";
						my @tmp_var = ();
						my $cnt_var = 0;
						my $cnt_true = 0;

						for my $marIndex (0 .. $MAR_Parameter-1){
							# Double Power Rail
							$powerRailIndex = ceil($marIndex / ($trackEachRow + 2));
							if ( ($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($powerRailFlag < $powerRailIndex) ){
								$powerRailFlag++;
								$newRow++;
								next;
							}
							else{
								$tmp_str="GF_V_$varName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								$tmp_str="GB_V_$varName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								$newRow++;
								$varName = $vertices{$varName}[5][3];
								if ($varName eq "null"){
									last;
								}
							}
						}
						if($cnt_true>0){
							if($cnt_true>1){
								print "[ERROR] MAR : more than one G Variables are true!!!\n";
								exit(-1);
							}
							else{
								for my $i(0 .. $#tmp_var){
									if(!exists($h_assign{$tmp_var[$i]})){
										$h_assign_new{$tmp_var[$i]} = 0;
									}
								}
							}
						}
						else{
							if($cnt_var > 1){
								$str.="(assert ((_ at-most 1)";
								for my $i(0 .. $#tmp_var){
									$str.=" $tmp_var[$i]";
									cnt("l", 3);
								}
								$str.="))\n";
								cnt("c", 3);
							}
						}
					}
				}
			}
		}
		$str.="\n";
		print "has been written.\n";
	}

	print "a     8. Tip-to-Tip spacing rule ";
	$str.=";8. Tip-to-Tip Spacing Rule\n";
	if ( $EOL_Parameter == 0 ){
		print "is disable\n";
		$str.=";EOL is disable\n";
	}
	else{  # PRL Rule Enable /Disable
### Tip-to-Tip Spacing Rule to prevent from having too close metal tips.
### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
		$str.=";8-A. from Right Tip to Left Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # no DR on M1
			if ($metal % 2 == 0) {  # M2
				for my $row (0 .. $numTrackH-3) {
					
					# skip the EOL rule related with power Rail.
					if ($row == 0 || $row == ($numTrackH -3)){
#                    next;
					}

					for my $col (0 .. $numTrackV - 2) { 
						$vName = "m".$metal."r".$row."c".$col;

						# FR Direction Checking
						my $vName_FR = $vertices{$vName}[5][7];
						if ( ($vName_FR ne "null") && ($row != 0) && ($EOL_Parameter >= 2)) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GR_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $eolIndex (0 .. $EOL_Parameter-2){  
								$tmp_str="GL_V_$vName_FR";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($eolIndex != ($EOL_Parameter-2)){
									$vName_FR = $vertices{$vName_FR}[5][1];
									if ($vName_FR eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

						# R Direction Checking
						my $vName_R = $vertices{$vName}[5][1];
						if ($vName_R ne "null") {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							$tmp_str="GR_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $eolIndex (0 .. $EOL_Parameter-1){
								$tmp_str="GL_V_$vName_R";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($eolIndex != $EOL_Parameter-1){
									$vName_R = $vertices{$vName_R}[5][1];
									if ($vName_R eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

						# BR Direction Checking 
						my $vName_BR = $vertices{$vName}[5][9];
						if ( ($vName_BR ne "null") && ($row != $numTrackH - 3) && ($EOL_Parameter >= 2)) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							$tmp_str="GR_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $eolIndex (0 .. $EOL_Parameter-2){  
								$tmp_str="GL_V_$vName_BR";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($eolIndex != ($EOL_Parameter-2)){
									$vName_BR = $vertices{$vName_BR}[5][1];
									if ($vName_BR eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";

### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
		$str.=";8-B. from Left Tip to Right Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # no DR on M1
			if ($metal % 2 == 0) {
				for my $row (0 .. $numTrackH-3) {

					# skip the EOL rule related with power Rail.
					if ($row == 0 || $row == ($numTrackH -3 )){
#next;
					}

					for my $col (1 .. $numTrackV-1) {
						$vName = "m".$metal."r".$row."c".$col;

						# FL Direction Checking
						my $vName_FL = $vertices{$vName}[5][6];
						if (($vName_FL ne "null") && ($row != 0) && ($EOL_Parameter >= 2)) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GL_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}

							for my $eolIndex (0 .. $EOL_Parameter-2){  
								$tmp_str="GR_V_$vName_FL";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($eolIndex != ($EOL_Parameter-2)){
									$vName_FL = $vertices{$vName_FL}[5][0];
									if ($vName_FL eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

						# L Direction Checking
						my $vName_L = $vertices{$vName}[5][0];
						if ($vName_L ne "null") {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							$tmp_str="GL_V_$vName";

							for my $eolIndex (0 .. $EOL_Parameter-1){
								$tmp_str="GR_V_$vName_L";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($eolIndex != $EOL_Parameter-1){
									$vName_L = $vertices{$vName_L}[5][0];
									if ($vName_L eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

						# BL Direction Checking 
						my $vName_BL = $vertices{$vName}[5][8];
						if ( ($vName_BL ne "null") && ($row != $numTrackH - 3) && ($EOL_Parameter >= 2)) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;
							$tmp_str="GL_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $eolIndex (0 .. $EOL_Parameter-2){  
								$tmp_str="GR_V_$vName_BL";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($eolIndex != ($EOL_Parameter-2)){
									$vName_BL = $vertices{$vName_BL}[5][0];
									if ($vName_BL eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";


### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
#
##### one Power Rail vertice has 2 times cost of other vertices.
#
		$str.=";8-C. from Back Tip to Front Tips for each vertex\n";
		for my $metal (1 .. $numMetalLayer) { # no DR on M1
			if ($metal % 2 == 1) {
				for my $row (0 .. $numTrackH-4) {
					for my $col (0 .. $numTrackV-1) {
						if($metal==1 && $col % 2 == 1){
							next;
						}
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;

						# BL Direction Checking
						my $vName_BL = $vertices{$vName}[5][8];
						if (($metal >= 2 && $metal % 2 == 0) && ($vName_BL ne "null") && ($EOL_Parameter >= 2)) {
							my $newRow = $row + 1;
							if ( ($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($EOL_Parameter == 2)){ # Skip the BR Direction
								### Nothing
							}
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;
								$tmp_str="GB_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}

								my $powerRailFlag = 0; my $powerRailIndex = 0;
								for my $eolIndex (1 .. $EOL_Parameter-1){
									$powerRailIndex = ceil($eolIndex / ($trackEachRow + 2));
									if ( ($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($powerRailFlag < $powerRailIndex)){
										$powerRailFlag++;
										next;
									}
									$tmp_str="GF_V_$vName_BL";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									if ( ($eolIndex) < ($EOL_Parameter-1)){
										$vName_BL = $vertices{$vName_BL}[5][3];
										$newRow++;
										if (($vName_BL eq "null")){
											last;
										}
									}
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}

						# B Direction Checking
						my $vName_B = $vertices{$vName}[5][3];
						if ($vName_B ne "null") {
							my $newRow = $row + 1;
							if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($EOL_Parameter == 1)){ # Skip the B Direction
								### Nothing
							}
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;
								$tmp_str="GB_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								my $powerRailFlag = 0; my $powerRailIndex = 0;
								for my $eolIndex (1 .. ($metal==1?($EOL_Parameter-1):$EOL_Parameter)){
									$powerRailIndex = ceil($eolIndex / ($trackEachRow + 2));
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($powerRailFlag < $powerRailIndex )){
										$powerRailFlag++;
										next;
									}   
									$tmp_str="GF_V_$vName_B";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									if ($eolIndex < ($metal==1?($EOL_Parameter-1):$EOL_Parameter)){
										$vName_B = $vertices{$vName_B}[5][3];
										$newRow++;
										if ($vName_B eq "null"){
											last;
										}
									}
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}

						# BR Direction Checking 
						my $vName_BR = $vertices{$vName}[5][9];
						if (($metal>=2 && $metal % 2 == 0) && ($vName_BR ne "null") && ($EOL_Parameter >= 2)) {
							my $newRow = $row + 1;
							if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($EOL_Parameter == 2)){ # Skip the BL Direction
								### Nothing
							}   
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;
								$tmp_str="GB_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								my $powerRailFlag = 0; my $powerRailIndex = 0;
								for my $eolIndex (1 .. $EOL_Parameter-1){
									$powerRailIndex = ceil($eolIndex / ($trackEachRow + 2));
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($powerRailFlag < $powerRailIndex)){
										$powerRailFlag++;
										next;
									}
									$tmp_str="GF_V_$vName_BR";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									if ($eolIndex < ($EOL_Parameter-1)){
										$vName_BR = $vertices{$vName_BR}[5][3];
										$newRow++;
										if ($vName_BR eq "null"){
											last;
										}
									}
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";

### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
		$str.=";8-D. from Front Tip to Back Tips for each vertex\n";
		for my $metal (1 .. $numMetalLayer) { # no DR on M1
			if ($metal % 2 == 1) {
				for my $row (1 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {
						if($metal==1 && $col % 2 == 1){
							next;
						}
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;

						# FL Direction
						my $vName_FL = $vertices{$vName}[5][6];
						if (($metal>=2 && $metal % 2 == 0) && ($vName_FL ne "null") && ($EOL_Parameter >= 2)) {
							my $newRow = $row - 1;
							if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($EOL_Parameter == 2)){ # Skip the BR Direction
								### Nothing
							}
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;
								$tmp_str="GF_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								my $powerRailFlag = 0; my $powerRailIndex = 0;
								for my $eolIndex (1 .. $EOL_Parameter-1){
									$powerRailIndex = ceil($eolIndex / ($trackEachRow + 2));
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($powerRailFlag < $powerRailIndex)){
										$powerRailFlag++;
										next;
									}
									$tmp_str="GB_V_$vName_FL";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									if ( ($eolIndex) < ($EOL_Parameter-1)){
										$vName_FL = $vertices{$vName_FL}[5][2];
										$newRow--;
										if (($vName_FL eq "null")){
											last;
										}
									}
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}

						# F Direction Checking
						my $vName_F = $vertices{$vName}[5][2];
						if ($vName_F ne "null") {
							my $newRow = $row - 1;
							if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($EOL_Parameter == 1)){ # Skip the B Direction
								### Nothing
							}
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;
								$tmp_str="GF_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								my $powerRailFlag = 0; my $powerRailIndex = 0;
								for my $eolIndex (1 .. ($metal==1?($EOL_Parameter-1):$EOL_Parameter)){
									$powerRailIndex = ceil($eolIndex / ($trackEachRow + 2));
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($powerRailFlag < $powerRailIndex )){
										$powerRailFlag++;
										next;
									}   
									$tmp_str="GB_V_$vName_F";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									if ($eolIndex < ($metal==1?($EOL_Parameter-1):$EOL_Parameter)){
										$vName_F = $vertices{$vName_F}[5][2];
										$newRow--;
										if ($vName_F eq "null"){
											last;
										}
									}
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}

						# FR Direction
						my $vName_FR = $vertices{$vName}[5][7];
						if (($metal>=2 && $metal == 0) && ($vName_FR ne "null") && ($EOL_Parameter >= 2)) {
							my $newRow = $row - 1;
							if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($EOL_Parameter == 2)){ # Skip the BR Direction
								### Nothing
							}
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;
								$tmp_str="GF_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								my $powerRailFlag = 0; my $powerRailIndex = 0;
								for my $eolIndex (1 .. $EOL_Parameter-1){
									$powerRailIndex = ceil($eolIndex / ($trackEachRow + 2));
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($powerRailFlag < $powerRailIndex)){
										$powerRailFlag++;
										next;
									}
									$tmp_str="GB_V_$vName_FR";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									if ( ($eolIndex) < ($EOL_Parameter-1)){
										$vName_FR = $vertices{$vName_FR}[5][2];
										$newRow--;
										if (($vName_FR eq "null")){
											last;
										}
									}
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] TIP2TIP : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";
		print "has been written.\n";
	}

	print "a     9. Via-to-via spacing rule ";
	$str.=";9. Via-to-Via Spacing Rule\n";
	if ( $VR_Parameter == 0 ){
		print "is disable\n";
		$str.=";VR is disable\n";
	}
	else{  # VR Rule Enable /Disable
### Via-to-Via Spacing Rule to prevent from having too close vias and stacked vias.
### UNDIRECTED_EDGE [index] [Term1] [Term2] [Cost]
### VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
		my $maxDistRow = $numTrackH-1;
		my $maxDistCol = $numTrackV-1;

		#for my $metal (1 .. $numMetalLayer) { # no DR on M1
		for my $metal (1 .. 1) { # no DR on M1
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {            
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					if (($row == $numTrackH-3) && ($col == $numTrackV-1)) {
						next;
					}
					# Via-to-via Spacing Rule
					$vName = "m".$metal."r".$row."c".$col;
					if ($vertices{$vName}[5][4] ne "null") { # Up Neighbor, i.e., VIA from the vName vertex.
						my $tmp_str="";
						my @tmp_var = ();
						my $cnt_var = 0;
						my $cnt_true = 0;
						$tmp_str="M_$vName\_$vertices{$vName}[5][4]";
						if(!exists($h_assign{$tmp_str})){
							push(@tmp_var, $tmp_str);
							setVar($tmp_str, 2);
							$cnt_var++;
						}
						elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
							setVar_wo_cnt($tmp_str, 0);
							$cnt_true++;
						}

						for my $newRow ($row .. $numTrackH-3) {
							for my $newCol ($col .. $numTrackV-1) {
								my $distCol = $newCol - $col;
								my $distRow = $newRow - $row;

								# Check power rail between newRow and row. (Double Power Rail Rule Applying
								if ( ($DoublePowerRail == 1) && (floor($newRow / ($trackEachRow + 1)) ne floor($row / ($trackEachRow + 1))) ){
									$distRow++;
								}
								if ( ($newRow eq $row) && ($newCol eq $col) ){  # Initial Value.
									next;
								}
								if ( ($distCol * $distCol + $distRow * $distRow) > ($VR_Parameter * $VR_Parameter) ){ # Check the Via Distance
									last;
								}
								
								###### # Need to consider the Power rail distance by 2 like EOL rule
								my $neighborName = $vName;
								while ($distCol > 0){
									$distCol--;
									$neighborName = $vertices{$neighborName}[5][1];
									if ($neighborName eq "null"){
										last;
									}
								}

								my $currentRow = $row; my $FlagforSecond = 0;
								while ($distRow > 0){  
									$distRow--; 
									$currentRow++;

									########### Double Power Rail Effective Flag Code --> We need to update previous PowerRailFlag with this code [Dongwon Park , 2019-01-08]
									if( ($DoublePowerRail == 1) && ($currentRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0) ){ #power Rail
										$FlagforSecond = 1;
										$currentRow--; 
										next;
									}
									$FlagforSecond = 0;
									####################################
									$neighborName = $vertices{$neighborName}[5][3];
									if ($neighborName eq "null"){
										last;
									}
								}
								my $neighborUp = "";
								if ($neighborName ne "null"){
									$neighborUp = $vertices{$neighborName}[5][4];
									if ($neighborUp eq "null"){
										print "ERROR : There is some bug in switch box definition !\n";
										print "$vName\n";
										exit(-1);
									}
								}
								my $col_neighbor = (split /[mrc]/, $neighborName)[3];
								if($metal > 1 && $metal % 2 == 1 && ($col_neighbor %2 == 1)){
									next;
								}
								else{
									$tmp_str="M_$neighborName\_$neighborUp";                        
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
								}
							}
						}
						if($cnt_true>0){
							if($cnt_true>1){
								print "[ERROR] VIA2VIA: more than one G Variables are true!!!\n";
								exit(-1);
							}
							else{
								for my $i(0 .. $#tmp_var){
									if(!exists($h_assign{$tmp_var[$i]})){
										$h_assign_new{$tmp_var[$i]} = 0;
									}
								}
							}
						}
						else{
							if($cnt_var > 1){
								$str.="(assert ((_ at-most 1)";
								for my $i(0 .. $#tmp_var){
									$str.=" $tmp_var[$i]";
									cnt("l", 3);
								}
								$str.="))\n";
								cnt("c", 3);
							}
						}
					}
				}
			}
		}
		$str.=";VIA Rule for M2~M4, VIA Rule is applied only for vias between different nets\n";
		for my $netIndex (0 .. $#nets) {
			for my $metal (2 .. $numMetalLayer-1) { # no DR on M1
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {            
						if($metal>1 && $col % 2 == 1){
							next;
						}
						if (($row == $numTrackH-3) && ($col == $numTrackV-1)) {
							next;
						}
						# Via-to-via Spacing Rule
						$vName = "m".$metal."r".$row."c".$col;
						if ($vertices{$vName}[5][4] ne "null") { # Up Neighbor, i.e., VIA from the vName vertex.
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="N$nets[$netIndex][1]_E_$vName\_$vertices{$vName}[5][4]";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}

							for my $newRow ($row .. $numTrackH-3) {
								for my $newCol ($col .. $numTrackV-1) {
									my $distCol = $newCol - $col;
									my $distRow = $newRow - $row;

									# Check power rail between newRow and row. (Double Power Rail Rule Applying
									if ( ($DoublePowerRail == 1) && (floor($newRow / ($trackEachRow + 1)) ne floor($row / ($trackEachRow + 1))) ){
										$distRow++;
									}
									if ( ($newRow eq $row) && ($newCol eq $col) ){  # Initial Value.
										next;
									}
									if ( ($distCol * $distCol + $distRow * $distRow) > ($VR_Parameter * $VR_Parameter) ){ # Check the Via Distance
										last;
									}
									
									###### # Need to consider the Power rail distance by 2 like EOL rule
									my $neighborName = $vName;
									while ($distCol > 0){
										$distCol--;
										$neighborName = $vertices{$neighborName}[5][1];
										if ($neighborName eq "null"){
											last;
										}
									}

									my $currentRow = $row; my $FlagforSecond = 0;
									while ($distRow > 0){  
										$distRow--; 
										$currentRow++;

										########### Double Power Rail Effective Flag Code --> We need to update previous PowerRailFlag with this code [Dongwon Park , 2019-01-08]
										if( ($DoublePowerRail == 1) && ($currentRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0) ){ #power Rail
											$FlagforSecond = 1;
											$currentRow--; 
											next;
										}
										$FlagforSecond = 0;
										####################################
										$neighborName = $vertices{$neighborName}[5][3];
										if ($neighborName eq "null"){
											last;
										}
									}
									my $neighborUp = "";
									if ($neighborName ne "null"){
										$neighborUp = $vertices{$neighborName}[5][4];
										if ($neighborUp eq "null"){
											print "ERROR : There is some bug in switch box definition !\n";
											print "$vName\n";
											exit(-1);
										}
									}
									my $col_neighbor = (split /[mrc]/, $neighborName)[3];
									if($metal > 1 && ($col_neighbor%2 == 1)){
										next;
									}
									else{
										$tmp_str="C_VIA_WO_N$nets[$netIndex][1]_E_$neighborName\_$neighborUp";                        
										if(!exists($h_assign{$tmp_str})){
											push(@tmp_var, $tmp_str);
											setVar($tmp_str, 2);
											$cnt_var++;
										}
										elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
											setVar_wo_cnt($tmp_str, 0);
											$cnt_true++;
										}
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] VIA2VIA: more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		for my $metal (2 .. $numMetalLayer-1) { # no DR on M1
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {            
					if($metal>1 && $col % 2 == 1){
						next;
					}
					if (($row == $numTrackH-3) && ($col == $numTrackV-1)) {
						next;
					}
					# Via-to-via Spacing Rule
					$vName = "m".$metal."r".$row."c".$col;
					if ($vertices{$vName}[5][4] ne "null") { # Up Neighbor, i.e., VIA from the vName vertex.

						for my $newRow ($row .. $numTrackH-3) {
							for my $newCol ($col .. $numTrackV-1) {
								my $distCol = $newCol - $col;
								my $distRow = $newRow - $row;

								# Check power rail between newRow and row. (Double Power Rail Rule Applying
								if ( ($DoublePowerRail == 1) && (floor($newRow / ($trackEachRow + 1)) ne floor($row / ($trackEachRow + 1))) ){
									$distRow++;
								}
								if ( ($newRow eq $row) && ($newCol eq $col) ){  # Initial Value.
									next;
								}
								if ( ($distCol * $distCol + $distRow * $distRow) > ($VR_Parameter * $VR_Parameter) ){ # Check the Via Distance
									last;
								}
								
								###### # Need to consider the Power rail distance by 2 like EOL rule
								my $neighborName = $vName;
								while ($distCol > 0){
									$distCol--;
									$neighborName = $vertices{$neighborName}[5][1];
									if ($neighborName eq "null"){
										last;
									}
								}

								my $currentRow = $row; my $FlagforSecond = 0;
								while ($distRow > 0){  
									$distRow--; 
									$currentRow++;

									########### Double Power Rail Effective Flag Code --> We need to update previous PowerRailFlag with this code [Dongwon Park , 2019-01-08]
									if( ($DoublePowerRail == 1) && ($currentRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0) ){ #power Rail
										$FlagforSecond = 1;
										$currentRow--; 
										next;
									}
									$FlagforSecond = 0;
									####################################
									$neighborName = $vertices{$neighborName}[5][3];
									if ($neighborName eq "null"){
										last;
									}
								}
								my $neighborUp = "";
								if ($neighborName ne "null"){
									$neighborUp = $vertices{$neighborName}[5][4];
									if ($neighborUp eq "null"){
										print "ERROR : There is some bug in switch box definition !\n";
										print "$vName\n";
										exit(-1);
									}
								}
								my $col_neighbor = (split /[mrc]/, $neighborName)[3];
								if($metal > 1 && ($col_neighbor%2 == 1)){
									next;
								}
								else{
									for my $netIndex (0 .. $#nets) {
										my $tmp_str_c="";
										my $tmp_str="";
										my @tmp_var = ();
										my $cnt_var = 0;
										my $cnt_true = 0;
										$tmp_str_c="C_VIA_WO_N$nets[$netIndex][1]_E_$neighborName\_$neighborUp";                        
										if(exists($h_var{$tmp_str_c})){
											for my $netIndex_sub (0 .. $#nets) {
												if($netIndex == $netIndex_sub){
													next;
												}
												$tmp_str="N$nets[$netIndex_sub][1]_E_$neighborName\_$neighborUp";                        
												if(!exists($h_assign{$tmp_str})){
													push(@tmp_var, $tmp_str);
													setVar($tmp_str, 2);
													$cnt_var++;
												}
												elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
													setVar_wo_cnt($tmp_str, 0);
													$cnt_true++;
												}
											}
										}
										if($cnt_true>0){
											if($cnt_true>1){
												print "[ERROR] VIA2VIA: more than one G Variables are true!!!\n";
												exit(-1);
											}
											else{
												for my $i(0 .. $#tmp_var){
													if(!exists($h_assign{$tmp_var[$i]})){
														$h_assign_new{$tmp_var[$i]} = 0;
													}
												}
											}
										}
										else{
											if($cnt_var > 1){
												$str.="(assert (= $tmp_str_c (or";
												for my $i(0 .. $#tmp_var){
													$str.=" $tmp_var[$i]";
													cnt("l", 3);
												}
												$str.=")))\n";
												cnt("c", 3);
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
		print "has been written.\n";
	}

	print "a     10. Parallel Run Length Rule ";
	$str.=";10. Parallel Run Length Rule\n";
	if ( $PRL_Parameter == 0 ){
		print "is disable....\n";
		$str.=";PRL is disable\n";
	}
	else{  # PRL Rule Enable /Disable
### Paralle Run-Length Rule to prevent from having too close metal tips.
### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
		$str.=";11-A. from Right Tip to Left Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # no DR on M1
			if ($metal % 2 == 0) {  # M2
				for my $row (0 .. $numTrackH-3) {
					# skip the PRL rule related with power Rail.
					if ($row == 0 || $row == $numTrackH - 3){
#next;
					}
					for my $col (0 .. $numTrackV - 1) { # 
						$vName = "m".$metal."r".$row."c".$col;
						# F Direction Checking
						my $vName_F = $vertices{$vName}[5][2];
						if ( ($vName_F ne "null") && ($row  != 0) ) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GR_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $prlIndex (0 .. $PRL_Parameter-1){  
								$tmp_str="GL_V_$vName_F";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($prlIndex != ($PRL_Parameter-1)){
									$vName_F = $vertices{$vName_F}[5][0];
									if ($vName_F eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] PRL : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
						# B Direction Checking 
						my $vName_B = $vertices{$vName}[5][3];
						if ( ($vName_B ne "null") && ($row != $numTrackH - 3)) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GR_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $prlIndex (0 .. $PRL_Parameter-1){  
								$tmp_str="GL_V_$vName_B";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($prlIndex != ($PRL_Parameter-1)){
									$vName_B = $vertices{$vName_B}[5][0];
									if ($vName_B eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] PRL : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";


		###### Skip to check exact adjacent GV variable, (From right to left is enough), 11-B is executed when PRL_Parameter > 1
		$str.=";11-B. from Left Tip to Right Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # no DR on M1
			if ($metal % 2 == 0) {  # M2
				for my $row (0 .. $numTrackH-3) {
					# skip the PRL rule related with power Rail.
					if ($row == 0 || $row == $numTrackH - 3){
#next;
					}
					for my $col (0 .. $numTrackV - 1) { # 
						$vName = "m".$metal."r".$row."c".$col;
						# FR Direction Checking
						my $vName_FR = $vertices{$vName}[5][7];
						if ( ($vName_FR ne "null") && ($row != 0) && ($PRL_Parameter > 1) ) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GL_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $prlIndex (0 .. $PRL_Parameter-1){  
								if ($prlIndex != ($PRL_Parameter-1)){
									$tmp_str="GR_V_$vName_FR";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									$vName_FR = $vertices{$vName_FR}[5][1];
									if ($vName_FR eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] PRL : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
						# BR Direction Checking 
						my $vName_BR = $vertices{$vName}[5][9];
						if ( ($vName_BR ne "null") && ($row != $numTrackH - 3) && ($PRL_Parameter > 1) ) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GL_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $prlIndex (0 .. $PRL_Parameter-1){  
								if ($prlIndex != ($PRL_Parameter-1)){
									$tmp_str="GR_V_$vName_BR";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									$vName_BR = $vertices{$vName_BR}[5][1];
									if ($vName_BR eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] PRL : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";

### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
#
##### one Power Rail vertice has 2 times cost of other vertices. ($Double Power Rail)
#
		$str.=";11-C. from Back Tip to Front Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # no DR on M1
			last;
			if ($metal % 2 == 1) {
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;
						# Left Track Checking
						my $vName_L = $vertices{$vName}[5][0];
						if ($vName_L ne "null") {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GB_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							$tmp_str="GF_V_$vName_L";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							if ($PRL_Parameter > 1){
								my $newRow = $row-1;
								my $FlagforSecond = 0;
								for my $prlIndex (0 .. $PRL_Parameter-2){
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0)){
										$FlagforSecond = 1;
										next;
									}   
									$FlagforSecond = 0;
									$vName_L = $vertices{$vName_L}[5][2];
									if ($vName_L eq "null"){
										last;
									}
									$tmp_str="GF_V_$vName_L";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									$newRow--;
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] PRL : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
						# Right Track Checking
						my $vName_R = $vertices{$vName}[5][1];
						if ($vName_R ne "null") {
							$tmp_str="GB_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							$tmp_str="GF_V_$vName_R";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							if ($PRL_Parameter > 1){
								my $newRow = $row-1;
								my $FlagforSecond = 0;
								for my $prlIndex (0 .. $PRL_Parameter-2){
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0)){
										$FlagforSecond = 1;
										next;
									}   
									$FlagforSecond = 0;
									$vName_R = $vertices{$vName_R}[5][2];
									if ($vName_R eq "null"){
										last;
									}
									$tmp_str="GF_V_$vName_R";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									$newRow--;
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] PRL : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

					}
				}
			}
		}
		$str.="\n";

		###### Skip to check exact adjacent GV variable, (From right to left is enough), 11-B is executed when PRL_Parameter > 1
		$str.=";11-D. from Front Tip to Back Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # no DR on M1
			last;
			if ($metal % 2 == 1) {
				for my $row (0 .. $numTrackH-4) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;
						# Left Track Checking
						my $vName_L = $vertices{$vName}[5][0];
						if (($vName_L ne "null") && ($PRL_Parameter > 1)) { 
							my $newRow = $row+1;
							if( ($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($PRL_Parameter == 2)) {
								#### Nothing
							}
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;

								$tmp_str="GF_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								my $FlagforSecond = 0;
								for my $prlIndex (0 .. $PRL_Parameter-2){
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0)){
										$FlagforSecond = 1;
										next;
									}   
									$FlagforSecond = 0;
									$vName_L = $vertices{$vName_L}[5][3];
									if ($vName_L eq "null"){
										last;
									}
									$tmp_str="GB_V_$vName_L";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									$newRow++;
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] PRL : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}

						# Right Track Checking
						my $vName_R = $vertices{$vName}[5][1];
						if (($vName_R ne "null") && ($PRL_Parameter > 1)) { 
							my $newRow = $row+1;
							if( ($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($PRL_Parameter == 2)) {
								#### Nothing
							}
							else{
								my $tmp_str="";
								my @tmp_var = ();
								my $cnt_var = 0;
								my $cnt_true = 0;

								$tmp_str="GF_V_$vName";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								my $FlagforSecond = 0;
								for my $prlIndex (0 .. $PRL_Parameter-2){
									if (($DoublePowerRail == 1) && ($newRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0)){
										$FlagforSecond = 1;
										next;
									}   
									$FlagforSecond = 0;
									$vName_R = $vertices{$vName_R}[5][3];
									if ($vName_R eq "null"){
										last;
									}
									$tmp_str="GB_V_$vName_R";
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
									$newRow++;
								}
								if($cnt_true>0){
									if($cnt_true>1){
										print "[ERROR] PRL : more than one G Variables are true!!!\n";
										exit(-1);
									}
									else{
										for my $i(0 .. $#tmp_var){
											if(!exists($h_assign{$tmp_var[$i]})){
												$h_assign_new{$tmp_var[$i]} = 0;
											}
										}
									}
								}
								else{
									if($cnt_var > 1){
										$str.="(assert ((_ at-most 1)";
										for my $i(0 .. $#tmp_var){
											$str.=" $tmp_var[$i]";
											cnt("l", 3);
										}
										$str.="))\n";
										cnt("c", 3);
									}
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";
		print "has been written.\n";
	}
	print "a     11. Net Consistency";
	$str.=";11. Net Consistency\n";
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
	# All Net Variables should be connected to flow variable though it is nor a direct connection
	if($numMetalLayer>2){
#for my $netIndex (0 .. $#nets) {
		my %h_tmp = ();
		foreach my $net(sort(keys %h_extnets)){
			my $netIndex = $h_idx{$net};
			for my $metal ($numMetalLayer-1 .. $numMetalLayer-1) {   
				for my $col (0 .. $numTrackV-1) {
					if(!exists($h_tmp{$net."_".$col})){
						for my $row (0 .. $numTrackH-3) {
							if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
								next;
							}
							$vName = "m".$metal."r".$row."c".$col;
							for my $i (0 .. $#{$vedge_out{$vName}}){ # incoming
								for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
									if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex] && $virtualEdges[$vedge_out{$vName}[$i]][2] eq $keySON){
										if(!exists($h_tmp{$net."_".$col})){
											$h_tmp{$net."_".$col} = 1;
										}
										my $tmp_str_e ="N$nets[$netIndex][1]\_";
										$tmp_str_e.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
										if(!exists($h_assign{$tmp_str_e}) || exists($h_assign{$tmp_str_e}) && $h_assign{$tmp_str_e} eq 1){
											for my $row2 (0 .. $numTrackH-3) {
												my $vName2 = "m".$metal."r".$row2."c".$col;
												my $tmp_str = "";
												my @tmp_var_self = ();
												my @tmp_var_self_c = ();
												my $cnt_var_self = 0;
												my $cnt_var_self_c = 0;
												my $cnt_true_self = 0;
												my $cnt_true_self_c = 0;

												if(exists($vertices{$vName2}) && $vertices{$vName2}[5][3] ne "null"){
													$tmp_str = "N$nets[$netIndex][1]\_E_$vName2\_$vertices{$vName2}[5][3]";
													if(!exists($h_assign{$tmp_str})){
														push(@tmp_var_self, $tmp_str);
														setVar($tmp_str, 2);
														$cnt_var_self++;
													}
													elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
														setVar_wo_cnt($tmp_str, 2);
														$cnt_true_self++;
													}
													for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
														$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName2\_$vertices{$vName2}[5][3]";
														if(!exists($h_assign{$tmp_str})){
															push(@tmp_var_self_c, $tmp_str);
															setVar($tmp_str, 2);
															$cnt_var_self_c++;
														}
														elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
															setVar_wo_cnt($tmp_str, 2);
															$cnt_true_self_c++;
														}
													}
													if(!exists($h_assign{$tmp_str_e})){
														setVar($tmp_str_e, 2);
														$str.="(assert (ite (and (= N$net\_M2_TRACK false) (= $tmp_str_e true)";
														cnt("l", 3);
													}
													elsif(exists($h_assign{$tmp_str_e}) && $h_assign{$tmp_str_e} eq 1){
														setVar_wo_cnt($tmp_str_e, 0);
														$str.="(assert (ite (and (= N$net\_M2_TRACK false)";
													}
													$str.=" (= $tmp_var_self[0] true)";
													for my $i(0 .. $#tmp_var_self_c){
														$str.=" (= $tmp_var_self_c[$i] false)";
														cnt("l", 3);
													}
													$str.=") ((_ at-least 1)";
													my @tmp_var_com = ();
													my $cnt_var_com = 0;
													my $cnt_true_com = 0;
													my $vName3 = "m".$metal."r".($row2+1)."c".$col;
													if(exists($vertices{$vName3}) && $vertices{$vName3}[5][3] ne "null"){
														for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
															$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName3\_$vertices{$vName3}[5][3]";
															if(!exists($h_assign{$tmp_str})){
																push(@tmp_var_com, $tmp_str);
																setVar($tmp_str, 2);
																$cnt_var_com++;
															}
															elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																setVar_wo_cnt($tmp_str, 2);
																$cnt_true_com++;
															}
														}
													}
													if(exists($vertices{$vName3}) && $vertices{$vName3}[5][5] ne "null"){
														for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
															$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vertices{$vName3}[5][5]\_$vName3";
															if(!exists($h_assign{$tmp_str})){
																push(@tmp_var_com, $tmp_str);
																setVar($tmp_str, 2);
																$cnt_var_com++;
															}
															elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																setVar_wo_cnt($tmp_str, 2);
																$cnt_true_com++;
															}
														}
													}
													if(exists($vertices{$vName3}) && $vertices{$vName3}[5][4] ne "null"){
														for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
															$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName3\_$vertices{$vName3}[5][4]";
															if(!exists($h_assign{$tmp_str})){
																push(@tmp_var_com, $tmp_str);
																setVar($tmp_str, 2);
																$cnt_var_com++;
															}
															elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																setVar_wo_cnt($tmp_str, 2);
																$cnt_true_com++;
															}
														}
													}
													if($cnt_true_com==0){
														if($cnt_var_com==1){
															for my $m(0 .. $#tmp_var_com){
																$str.=" $tmp_var_com[$m]";
																cnt("l", 3);
															}
														}
														elsif($cnt_var_com>=1){
															$str.=" (or";
															for my $m(0 .. $#tmp_var_com){
																$str.=" $tmp_var_com[$m]";
																cnt("l", 3);
															}
															$str.=")";
														}
													}
													for my $row3 ($row2+1 .. $numTrackH-3){
														my @tmp_var_net = ();
														my @tmp_var_com = ();
														my $cnt_var_net = 0;
														my $cnt_var_com = 0;
														my $cnt_true_net = 0;
														my $cnt_true_com = 0;
														for my $j (0 .. $row3-$row2-1){
															my $vName2 = "m".$metal."r".($row2+1+$j)."c".($col);
															if(exists($vertices{$vName2}) && $vertices{$vName2}[5][3] ne "null"){
																$tmp_str = "N$nets[$netIndex][1]\_E_$vName2\_$vertices{$vName2}[5][3]";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_net, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_net++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_net++;
																}
															}
														}
														my $vName3 = "m".$metal."r".($row3+1)."c".($col);
														if(exists($vertices{$vName3}) && $vertices{$vName3}[5][3] ne "null"){
															for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
																$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName3\_$vertices{$vName3}[5][3]";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_com, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_com++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_com++;
																}
															}
														}
														if(exists($vertices{$vName3}) && $vertices{$vName3}[5][5] ne "null"){
															for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
																$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vertices{$vName3}[5][5]\_$vName3";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_com, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_com++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_com++;
																}
															}
														}
														if(exists($vertices{$vName3}) && $vertices{$vName3}[5][4] ne "null"){
															for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
																$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName3\_$vertices{$vName3}[5][4]";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_com, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_com++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_com++;
																}
															}
														}
														if($cnt_true_com==0){
															if($cnt_var_com==1){
																for my $m(0 .. $#tmp_var_com){
																	$str.=" (and $tmp_var_com[$m]";
																	cnt("l", 3);
																}
																for my $m(0 .. $#tmp_var_net){
																	$str.=" $tmp_var_net[$m]";
																	cnt("l", 3);
																}
																$str.=")";
															}
															elsif($cnt_var_com>=1){
																$str.=" (and (or";
																for my $m(0 .. $#tmp_var_com){
																	$str.=" $tmp_var_com[$m]";
																	cnt("l", 3);
																}
																$str.=")";
																for my $m(0 .. $#tmp_var_net){
																	$str.=" $tmp_var_net[$m]";
																	cnt("l", 3);
																}
																$str.=")";
															}
														}
													}

													my @tmp_var_com = ();
													my $cnt_var_com = 0;
													my $cnt_true_com = 0;
													my $vName3 = "m".$metal."r".$row2."c".($col);
													if(exists($vertices{$vName3}) && $vertices{$vName3}[5][2] ne "null"){
														for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
															$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vertices{$vName3}[5][2]\_$vName3";
															if(!exists($h_assign{$tmp_str})){
																push(@tmp_var_com, $tmp_str);
																setVar($tmp_str, 2);
																$cnt_var_com++;
															}
															elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																setVar_wo_cnt($tmp_str, 2);
																$cnt_true_com++;
															}
														}
													}
													if(exists($vertices{$vName3}) && $vertices{$vName3}[5][5] ne "null"){
														for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
															$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vertices{$vName3}[5][5]\_$vName3";
															if(!exists($h_assign{$tmp_str})){
																push(@tmp_var_com, $tmp_str);
																setVar($tmp_str, 2);
																$cnt_var_com++;
															}
															elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																setVar_wo_cnt($tmp_str, 2);
																$cnt_true_com++;
															}
														}
													}
													if(exists($vertices{$vName3}) && $vertices{$vName3}[5][4] ne "null"){
														for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
															$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName3\_$vertices{$vName3}[5][4]";
															if(!exists($h_assign{$tmp_str})){
																push(@tmp_var_com, $tmp_str);
																setVar($tmp_str, 2);
																$cnt_var_com++;
															}
															elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																setVar_wo_cnt($tmp_str, 2);
																$cnt_true_com++;
															}
														}
													}
													if($cnt_true_com==0){
														if($cnt_var_com==1){
															for my $m(0 .. $#tmp_var_com){
																$str.=" $tmp_var_com[$m]";
																cnt("l", 3);
															}
														}
														elsif($cnt_var_com>=1){
															$str.=" (or";
															for my $m(0 .. $#tmp_var_com){
																$str.=" $tmp_var_com[$m]";
																cnt("l", 3);
															}
															$str.=")";
														}
													}
													for my $row3 (0 .. $row2-1){
														my @tmp_var_net = ();
														my @tmp_var_com = ();
														my $cnt_var_net = 0;
														my $cnt_var_com = 0;
														my $cnt_true_net = 0;
														my $cnt_true_com = 0;
														for my $j (0 .. $row3){
															my $vName2 = "m".$metal."r".($row2-$j)."c".($col);
															if(exists($vertices{$vName2}) && $vertices{$vName2}[5][2] ne "null"){
																$tmp_str = "N$nets[$netIndex][1]\_E_$vertices{$vName2}[5][2]\_$vName2";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_net, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_net++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_net++;
																}
															}
														}
														my $vName3 = "m".$metal."r".($row2-$row3-1)."c".($col);
														if(exists($vertices{$vName3}) && $vertices{$vName3}[5][2] ne "null"){
															for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
																$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vertices{$vName3}[5][2]\_$vName3";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_com, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_com++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_com++;
																}
															}
														}
														if(exists($vertices{$vName3}) && $vertices{$vName3}[5][5] ne "null"){
															for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
																$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vertices{$vName3}[5][5]\_$vName3";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_com, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_com++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_com++;
																}
															}
														}
														if(exists($vertices{$vName3}) && $vertices{$vName3}[5][4] ne "null"){
															for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
																$tmp_str = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$vName3\_$vertices{$vName3}[5][4]";
																if(!exists($h_assign{$tmp_str})){
																	push(@tmp_var_com, $tmp_str);
																	setVar($tmp_str, 2);
																	$cnt_var_com++;
																}
																elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} == 1){
																	setVar_wo_cnt($tmp_str, 2);
																	$cnt_true_com++;
																}
															}
														}
														if($cnt_true_com==0){
															if($cnt_var_com==1){
																for my $m(0 .. $#tmp_var_com){
																	$str.=" (and $tmp_var_com[$m]";
																	cnt("l", 3);
																}
																for my $m(0 .. $#tmp_var_net){
																	$str.=" $tmp_var_net[$m]";
																	cnt("l", 3);
																}
																$str.=")";
															}
															elsif($cnt_var_com>=1){
																$str.=" (and (or";
																for my $m(0 .. $#tmp_var_com){
																	$str.=" $tmp_var_com[$m]";
																	cnt("l", 3);
																}
																$str.=")";
																for my $m(0 .. $#tmp_var_net){
																	$str.=" $tmp_var_net[$m]";
																	cnt("l", 3);
																}
																$str.=")";
															}
														}
													}
													$str.=") (= true true)))\n";
													cnt("c", 3);
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	print "\n";

	print "a     12. Pin Accessibility Rule ";
	$str.=";12. Pin Accessibility Rule\n";

#	### Pin Accessibility Rule : External Pin Nets(except VDD/VSS) should have at-least $MPL_Parameter true edges for top-Layer or (top-1) layer(with opening)
	my $metal = $numMetalLayer - 1;
	my %h_tmp = ();

	# Vertical
	foreach my $net(sort(keys %h_extnets)){
		my $netIndex = $h_idx{$net};
		for my $col (0 .. $numTrackV-1) {
			if(!exists($h_tmp{$net."_".$col})){
				for my $row (0 .. $numTrackH-3) {
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;
					for my $i (0 .. $#{$vedge_out{$vName}}){ # incoming
						for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
							if($virtualEdges[$vedge_out{$vName}[$i]][2] eq $nets[$netIndex][5][$commodityIndex] && $virtualEdges[$vedge_out{$vName}[$i]][2] eq $keySON){
								if(!exists($h_tmp{$net."_".$col})){
									$h_tmp{$net."_".$col} = 1;
								}
								my $tmp_str ="N$nets[$netIndex][1]\_";
								$tmp_str.="E_$vName\_$virtualEdges[$vedge_out{$vName}[$i]][2]";
								if(!exists($h_assign{$tmp_str})){
									setVar($tmp_str, 2);
									$str.="(assert (ite (and (= N$net\_M2_TRACK false) (= $tmp_str true)) ((_ at-least ".($MPL_Parameter).")";
									cnt("l", 3);
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$str.="(assert (ite (= N$net\_M2_TRACK false) ((_ at-least ".($MPL_Parameter).")";
								}
								for my $row2 (0 .. $numTrackH-3) {
									my $tmp_str2 = "";
									my @tmp_var = ();
									my $cnt_var = 0;
									my $cnt_true = 0;
									my @tmp_var_1 = ();
									my $cnt_var_1 = 0;
									my $cnt_true_1 = 0;

									my $vName2 = "m".$metal."r".$row2."c".$col;
									my $selfF = "";
									my $selfB = "";
									if(exists($vertices{$vName2}) && $vertices{$vName2}[5][2] ne "null"){
										$selfF = "N$net\_E_$vertices{$vName2}[5][2]\_$vName2";
										if(!exists($h_assign{$selfF})){
											push(@tmp_var_1, $selfF);
											setVar($selfF, 2);
											$cnt_var_1++;
										}
										elsif(exists($h_assign{$selfF}) && $h_assign{$selfF} == 1){
											setVar_wo_cnt($selfF, 2);
											$cnt_true_1++;
										}
									}
									if(exists($vertices{$vName2}) && $vertices{$vName2}[5][3] ne "null"){
										$selfB = "N$net\_E_$vName2\_$vertices{$vName2}[5][3]";
										if(!exists($h_assign{$selfB})){
											push(@tmp_var_1, $selfB);
											setVar($selfB, 2);
											$cnt_var_1++;
										}
										elsif(exists($h_assign{$selfB}) && $h_assign{$selfB} == 1){
											setVar_wo_cnt($selfB, 2);
											$cnt_true_1++;
										}
									}
									$str.=" (or";
									for my $mar(0 .. $MAR_Parameter){
										$cnt_var = 0;
										$cnt_true = 0;
										@tmp_var = ();
										# Upper Layer => Left = EOL, Right = EOL+MAR should be keepout region from other nets
										$vName2 = "m".($metal+1)."r".$row2."c".$col;
										for my $netIndex2 (0 .. $#nets) {
											if($nets[$netIndex2][1] ne $net){
												my $pre_vName = $vName2;
												for my $i(0 .. ($EOL_Parameter + $mar)){
													if(exists($vertices{$pre_vName}) && $vertices{$pre_vName}[5][0] ne "null"){
														$tmp_str2 = "N$nets[$netIndex2][1]_E_$vertices{$pre_vName}[5][0]\_$pre_vName";
														if(!exists($h_assign{$tmp_str2})){
															push(@tmp_var, $tmp_str2);
															setVar($tmp_str2, 2);
															$cnt_var++;
														}
														elsif(exists($h_assign{$tmp_str2}) && $h_assign{$tmp_str2} == 1){
															setVar_wo_cnt($tmp_str2, 2);
															$cnt_true++;
														}
														$pre_vName = $vertices{$pre_vName}[5][0];
													}
													else{
														next;
													}
												}
												$pre_vName = $vName2;
												for my $i(0 .. ($MAR_Parameter - $mar + $EOL_Parameter)){
													if(exists($vertices{$pre_vName}) && $vertices{$pre_vName}[5][1] ne "null"){
														$tmp_str2 = "N$nets[$netIndex2][1]_E_$pre_vName\_$vertices{$pre_vName}[5][1]";
														if(!exists($h_assign{$tmp_str2})){
															push(@tmp_var, $tmp_str2);
															setVar($tmp_str2, 2);
															$cnt_var++;
														}
														elsif(exists($h_assign{$tmp_str2}) && $h_assign{$tmp_str2} == 1){
															setVar_wo_cnt($tmp_str2, 2);
															$cnt_true++;
														}
														$pre_vName = $vertices{$pre_vName}[5][1];
													}
													else{
														next;
													}
												}
											}
										}
										if($cnt_true_1>0){
											if($cnt_true == 0){
												if($cnt_var == 1){
													$str.=" (= $tmp_var[0] false)";
													cnt("l", 3);
												}
												elsif($cnt_var>1){
													$str.=" (and";
													for my $m(0 .. $#tmp_var){
														$str.=" (= $tmp_var[$m] false)";
														cnt("l", 3);
													}
													$str.=")";
												}
											}
										}
										elsif($cnt_var_1>0){
											if($cnt_true == 0){
												if($cnt_var_1 == 1){
													$str.=" (and (= $tmp_var_1[0] true)";
													cnt("l", 3);
													for my $m(0 .. $#tmp_var){
														$str.=" (= $tmp_var[$m] false)";
														cnt("l", 3);
													}
													$str.=")";
												}
												else{
													$str.=" (and (or";
													for my $m(0 .. $#tmp_var_1){
														$str.=" (= $tmp_var_1[$m] true)";
														cnt("l", 3);
													}
													$str.=")";
													for my $m(0 .. $#tmp_var){
														$str.=" (= $tmp_var[$m] false)";
														cnt("l", 3);
													}
													$str.=")";
												}
											}
										}
									}
									$str.=")";
								}
								if(!exists($h_assign{$tmp_str}) || exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									$str.=") (= true true)))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
	}
#	
#	print "has been written.\n";
### Pin Accessibility Rule : any vias to the metal3 layer should be connected to metal3 in-layer
### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
	$str.= ";13-A. VIA enclosure for each normal vertex\n";
	for my $netIndex (0 .. $#nets) {
		for my $metal (1 .. $numMetalLayer-1) {
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal>1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;
					my $tmp1 = "N$nets[$netIndex][1]_E_$vName\_$vertices{$vName}[5][4]";
					my $vName_u = $vertices{$vName}[5][4];
					my $tmp3 = "";
					my $tmp4 = "";
				
					if($metal % 2 == 0){	
						$tmp3 = "N$nets[$netIndex][1]_E";
						# Front Vertex
						if ($vertices{$vName}[5][2] ne "null") {
							$tmp3.="_$vertices{$vName_u}[5][2]_$vName_u";
						}
						elsif ($vertices{$vName_u}[5][2] eq "null") {
							$tmp3 = "null";
						}
						# Back Vertex
						$tmp4 ="N$nets[$netIndex][1]_E";
						if ($vertices{$vName_u}[5][3] ne "null") {
							$tmp4.="_$vName_u\_$vertices{$vName_u}[5][3]";
						}
						elsif ($vertices{$vName_u}[5][3] eq "null") {
							$tmp4 = "null";
						}
					}
					else{
						$tmp3 = "N$nets[$netIndex][1]_E";
						# Left Vertex
						if ($vertices{$vName_u}[5][0] ne "null") {
							$tmp3.="_$vertices{$vName_u}[5][0]_$vName_u";
						}
						elsif ($vertices{$vName_u}[5][0] eq "null") {
							$tmp3 = "null";
						}
						# Right Vertex
						$tmp4 ="N$nets[$netIndex][1]_E";
						if ($vertices{$vName_u}[5][1] ne "null") {
							$tmp4.="_$vName_u\_$vertices{$vName_u}[5][1]";
						}
						elsif ($vertices{$vName_u}[5][1] eq "null") {
							$tmp4 = "null";
						}
					}
					if($tmp3 eq "null" || exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
						if($tmp4 eq "null" || exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
							setVar($tmp1, 6);
							$str.="(assert (ite (= $tmp1 true) (= true false) (= true true)))\n";
							cnt("l", 3);
							cnt("c", 3);
						}
						elsif($tmp4 ne "null" && !exists($h_assign{$tmp4})){
							setVar($tmp1, 6);
							setVar($tmp4, 6);
							$str.="(assert (ite (= $tmp1 true) (= $tmp4 true) (= true true)))\n";
							cnt("l", 3);
							cnt("l", 3);
							cnt("c", 3);
						}
					}
					elsif($tmp3 ne "null" && !exists($h_assign{$tmp3})){
						if($tmp4 eq "null" || exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
							setVar($tmp1, 6);
							setVar($tmp3, 6);
							$str.="(assert (ite (= $tmp1 true) (= $tmp3 true) (= true true)))\n";
							cnt("l", 3);
							cnt("l", 3);
							cnt("c", 3);
						}
						elsif($tmp4 ne "null" && !exists($h_assign{$tmp4})){
							setVar($tmp1, 6);
							setVar($tmp3, 6);
							setVar($tmp4, 6);
							$str.="(assert (ite (= $tmp1 true) ((_ at-least 1) $tmp3 $tmp4) (= true true)))\n";
							cnt("l", 3);
							cnt("l", 3);
							cnt("l", 3);
							cnt("c", 3);
						}
					}
				}
			}
		}
	}
	$str.="\n";
	$str.=";13-B. VIA enclosure for each normal vertex\n";
	$str.=";13-C. VIA23 for each vertex\n";
	foreach my $net(sort(keys %h_extnets)){
		my $netIndex = $h_idx{$net};
		for my $metal (3 .. 3) { # At the top-most metal layer, only vias exist.
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					$vName = "m".$metal."r".$row."c".$col;
					for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
						my $vName1 = $virtualEdges[$vedge_out{$vName}[$i]][1];
						my $vName2 = $virtualEdges[$vedge_out{$vName}[$i]][2];

						my $tmp1 = "N$net\_E_$vName1\_$vName2";
						my $tmp2 = "N$net\_E_$vertices{$vName}[5][5]\_$vName";
						
						my $tmp3 = "N$net\_E";
						# Front Vertex
						if ($vertices{$vName}[5][2] ne "null") {
							$tmp3.="_$vertices{$vName}[5][2]_$vName";
						}
						elsif ($vertices{$vName}[5][2] eq "null") {
							$tmp3.="_FrontEnd_$vName";
						}
						# Back Vertex
						my $tmp4 ="N$net\_E";
						if ($vertices{$vName}[5][3] ne "null") {
							$tmp4.="_$vName\_$vertices{$vName}[5][3]";
						}
						elsif ($vertices{$vName}[5][3] eq "null") {
							$tmp4.="_$vName\_BackEnd";
						}
						
						if(!exists($h_assign{$tmp1}) && !exists($h_assign{$tmp2})){
							if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
								if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
									setVar($tmp1, 6);
									setVar($tmp2, 6);
									$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) (= true false) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
								elsif(!exists($h_assign{$tmp4})){
									setVar($tmp1, 6);
									setVar($tmp2, 6);
									setVar($tmp4, 6);
									$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) (= $tmp4 true) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
							}
							elsif(!exists($h_assign{$tmp3})){
								if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
									setVar($tmp1, 6);
									setVar($tmp2, 6);
									setVar($tmp3, 6);
									$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) (= $tmp3 true) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
								elsif(!exists($h_assign{$tmp4})){
									setVar($tmp1, 6);
									setVar($tmp2, 6);
									setVar($tmp3, 6);
									setVar($tmp4, 6);
									$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) ((_ at-least 1) $tmp3 $tmp4) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
							}
						}
						elsif(exists($h_assign{$tmp1}) && $h_assign{$tmp1} == 1 && exists($h_assign{$tmp2}) && $h_assign{$tmp2} == 1){
							if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
								if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
									print "[ERROR] MPL : UNSAT Condition!!!\n";
									exit(-1);
								}
							}
						}
						elsif(exists($h_assign{$tmp1}) && $h_assign{$tmp1} == 1){
							if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
								if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
									setVar($tmp2, 6);
									$str.="(assert (ite (= $tmp2 true) (= true false) (= true true)))\n";
									cnt("l", 3);
									cnt("c", 3);
								}
								elsif(!exists($h_assign{$tmp4})){
									setVar($tmp2, 6);
									setVar($tmp4, 6);
									$str.="(assert (ite (= $tmp2 true) (= $tmp4 true) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
							}
							elsif(!exists($h_assign{$tmp3})){
								if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
									setVar($tmp2, 6);
									setVar($tmp3, 6);
									$str.="(assert (ite (= $tmp2 true) (= $tmp3 true) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
								elsif(!exists($h_assign{$tmp4})){
									setVar($tmp2, 6);
									setVar($tmp3, 6);
									setVar($tmp4, 6);
									$str.="(assert (ite (= $tmp2 true) ((_ at-least 1) $tmp3 $tmp4) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
							}
						}
						elsif(exists($h_assign{$tmp2}) && $h_assign{$tmp2} == 1){
							if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
								if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
									setVar($tmp1, 6);
									$str.="(assert (ite (= $tmp1 true) (= true false) (= true true)))\n";
									cnt("l", 3);
									cnt("c", 3);
								}
								elsif(!exists($h_assign{$tmp4})){
									setVar($tmp1, 6);
									setVar($tmp4, 6);
									$str.="(assert (ite (= $tmp1 true) (= $tmp4 true) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
							}
							elsif(!exists($h_assign{$tmp3})){
								if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
									setVar($tmp1, 6);
									setVar($tmp3, 6);
									$str.="(assert (ite (= $tmp1 true) (= $tmp3 true) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
								elsif(!exists($h_assign{$tmp4})){
									setVar($tmp1, 6);
									setVar($tmp3, 6);
									setVar($tmp4, 6);
									$str.="(assert (ite (= $tmp1 true) ((_ at-least 1) $tmp3 $tmp4) (= true true)))\n";
									cnt("l", 3);
									cnt("l", 3);
									cnt("l", 3);
									cnt("c", 3);
								}
							}
						}

					}
				}
			}
		}
	}
	$str.="\n";
	if($numMetalLayer>=4){
		$str.=";13-D. VIA34 for each vertex\n";
		foreach my $net(sort(keys %h_extnets)){
			my $netIndex = $h_idx{$net};
			for my $metal (3 .. 3) { # At the top-most metal layer, only vias exist.
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;
						for my $i (0 .. $#{$vedge_out{$vName}}){ # sink
							my $vName1 = $virtualEdges[$vedge_out{$vName}[$i]][1];
							my $vName2 = $virtualEdges[$vedge_out{$vName}[$i]][2];
							my $tmp1 = "N$net\_E_$vName1\_$vName2";
							my $tmp2 = "N$net\_E_$vName\_$vertices{$vName}[5][4]";
							
							my $tmp3 = "N$net\_E";
							# Front Vertex
							if ($vertices{$vName}[5][2] ne "null") {
								$tmp3.="_$vertices{$vName}[5][2]_$vName";
							}
							elsif ($vertices{$vName}[5][2] eq "null") {
								$tmp3.="_FrontEnd_$vName";
							}
							# Back Vertex
							my $tmp4 ="N$net\_E";
							if ($vertices{$vName}[5][3] ne "null") {
								$tmp4.="_$vName\_$vertices{$vName}[5][3]";
							}
							elsif ($vertices{$vName}[5][3] eq "null") {
								$tmp4.="_$vName\_BackEnd";
							}
							
							if(!exists($h_assign{$tmp1}) && !exists($h_assign{$tmp2})){
								if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
									if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
										setVar($tmp1, 6);
										setVar($tmp2, 6);
										$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) (= true false) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
									elsif(!exists($h_assign{$tmp4})){
										setVar($tmp1, 6);
										setVar($tmp2, 6);
										setVar($tmp4, 6);
										$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) (= $tmp4 true) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
								}
								elsif(!exists($h_assign{$tmp3})){
									if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
										setVar($tmp1, 6);
										setVar($tmp2, 6);
										setVar($tmp3, 6);
										$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) (= $tmp3 true) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
									elsif(!exists($h_assign{$tmp4})){
										setVar($tmp1, 6);
										setVar($tmp2, 6);
										setVar($tmp3, 6);
										setVar($tmp4, 6);
										$str.="(assert (ite (and (= $tmp1 true) (= $tmp2 true)) ((_ at-least 1) $tmp3 $tmp4) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
								}
							}
							elsif(exists($h_assign{$tmp1}) && $h_assign{$tmp1} == 1 && exists($h_assign{$tmp2}) && $h_assign{$tmp2} == 1){
								if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
									if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
										print "[ERROR] MPL : UNSAT Condition!!!\n";
										exit(-1);
									}
								}
							}
							elsif(exists($h_assign{$tmp1}) && $h_assign{$tmp1} == 1){
								if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
									if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
										setVar($tmp2, 6);
										$str.="(assert (ite (= $tmp2 true) (= true false) (= true true)))\n";
										cnt("l", 3);
										cnt("c", 3);
									}
									elsif(!exists($h_assign{$tmp4})){
										setVar($tmp2, 6);
										setVar($tmp4, 6);
										$str.="(assert (ite (= $tmp2 true) (= $tmp4 true) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
								}
								elsif(!exists($h_assign{$tmp3})){
									if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
										setVar($tmp2, 6);
										setVar($tmp3, 6);
										$str.="(assert (ite (= $tmp2 true) (= $tmp3 true) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
									elsif(!exists($h_assign{$tmp4})){
										setVar($tmp2, 6);
										setVar($tmp3, 6);
										setVar($tmp4, 6);
										$str.="(assert (ite (= $tmp2 true) ((_ at-least 1) $tmp3 $tmp4) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
								}
							}
							elsif(exists($h_assign{$tmp2}) && $h_assign{$tmp2} == 1){
								if(exists($h_assign{$tmp3}) && $h_assign{$tmp3} == 0){
									if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
										setVar($tmp1, 6);
										$str.="(assert (ite (= $tmp1 true) (= true false) (= true true)))\n";
										cnt("l", 3);
										cnt("c", 3);
									}
									elsif(!exists($h_assign{$tmp4})){
										setVar($tmp1, 6);
										setVar($tmp4, 6);
										$str.="(assert (ite (= $tmp1 true) (= $tmp4 true) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
								}
								elsif(!exists($h_assign{$tmp3})){
									if(exists($h_assign{$tmp4}) && $h_assign{$tmp4} == 0){
										setVar($tmp1, 6);
										setVar($tmp3, 6);
										$str.="(assert (ite (= $tmp1 true) (= $tmp3 true) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
									elsif(!exists($h_assign{$tmp4})){
										setVar($tmp1, 6);
										setVar($tmp3, 6);
										setVar($tmp4, 6);
										$str.="(assert (ite (= $tmp1 true) ((_ at-least 1) $tmp3 $tmp4) (= true true)))\n";
										cnt("l", 3);
										cnt("l", 3);
										cnt("l", 3);
										cnt("c", 3);
									}
								}
							}
						}

					}
				}
			}
		}
		$str.="\n";
	}
	print "has been written.\n";

	print "a     13. Step Height Rule ";
	$str.=";13. Step Height Rule\n";
	if ( $SHR_Parameter < 2 ){
		print "is disable.....\n";
		$str.=";SHR is disable\n";
	}
	else{

### Paralle Run-Length Rule to prevent from having too close metal tips.
### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
		$str.=";12-A. from Right Tip to Right Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
			if ($metal % 2 == 0) {  # M2
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV - 2) { # 
						$vName = "m".$metal."r".$row."c".$col;
						# FR Direction Checking
						my $vName_FR = $vertices{$vName}[5][7];
						if ($vName_FR ne "null") {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GR_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){  
								$tmp_str="GR_V_$vName_FR";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($shrIndex != ($SHR_Parameter-2)){
									$vName_FR = $vertices{$vName_FR}[5][1];
									if ($vName_FR eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
						# BR Direction Checking 
						my $vName_BR = $vertices{$vName}[5][9];
						if ($vName_BR ne "null") {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GR_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){  
								$tmp_str="GR_V_$vName_BR";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($shrIndex != ($SHR_Parameter-2)){
									$vName_BR = $vertices{$vName_BR}[5][1];
									if ($vName_BR eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";

		$str.=";12-B. from Left Tip to Left Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
			if ($metal % 2 == 0) {  # M2
				for my $row (0 .. $numTrackH-3) {
					for my $col (1 .. $numTrackV - 1) { # 
						$vName = "m".$metal."r".$row."c".$col;
						# FL Direction Checking
						my $vName_FL = $vertices{$vName}[5][6];
						if ($vName_FL ne "null") {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GL_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){  
								$tmp_str="GL_V_$vName_FL";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($shrIndex != ($SHR_Parameter-2)){
									$vName_FL = $vertices{$vName_FL}[5][0];
									if ($vName_FL eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
						# BL Direction Checking 
						my $vName_BL = $vertices{$vName}[5][8];
						if ($vName_BL ne "null") {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GL_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){  
								$tmp_str="GL_V_$vName_BL";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								if ($shrIndex != ($SHR_Parameter-2)){
									$vName_BL = $vertices{$vName_BL}[5][0];
									if ($vName_BL eq "null"){
										last;
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		$str.="\n";

		###### Skip to check exact adjacent GV variable, (From right to left is enough), 11-B is executed when PRL_Parameter > 1
		$str.="; 12-C. from Back Tip to Back Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
			if ($metal % 2 == 1) {
				for my $row (0 .. $numTrackH-4) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;
						
						# Left-Back Track Checking
						my $vName_LB = $vertices{$vName}[5][8];
						if (($vName_LB ne "null")) { 
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GB_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){
								$tmp_str="GB_V_$vName_LB";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								$vName_LB = $vertices{$vName_LB}[5][3];

								if ($vName_LB eq "null"){
									last;
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

						# Right-Back Track Checking
						my $vName_RB = $vertices{$vName}[5][9];
						if (($vName_RB ne "null")) { 
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GB_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){
								$tmp_str="GB_V_$vName_RB";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								$vName_RB = $vertices{$vName_RB}[5][3];
								if ($vName_RB eq "null"){
									last;
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

					}
				}
			}
		}
		$str.="\n";


################### DEBUGGING ###########################
		$str.=";12-D. from Front Tip to Front Tips for each vertex\n";
		for my $metal (2 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
			if ($metal % 2 == 1) {
				for my $row (1 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {
						if($metal>1 && $metal % 2 == 1){
							next;
						}
						$vName = "m".$metal."r".$row."c".$col;

						# Left-Front Direction
						my $vName_LF = $vertices{$vName}[5][6];
						if (($vName_LF ne "null")) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GF_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){
								$tmp_str="GF_V_$vName_LF";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								$vName_LF = $vertices{$vName_LF}[5][2];
								if (($vName_LF eq "null")){
									last;
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

						# Right-Front Direction
						my $vName_RF = $vertices{$vName}[5][7];
						if (($vName_RF ne "null")) {
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="GF_V_$vName";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}
							for my $shrIndex (0 .. $SHR_Parameter-2){
								$tmp_str="GF_V_$vName_RF";
								if(!exists($h_assign{$tmp_str})){
									push(@tmp_var, $tmp_str);
									setVar($tmp_str, 2);
									$cnt_var++;
								}
								elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
									setVar_wo_cnt($tmp_str, 0);
									$cnt_true++;
								}
								$vName_RF = $vertices{$vName_RF}[5][2];
								if (($vName_RF eq "null")){
									last;
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] SHR : more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}

					}
				}
			}
		}
		$str.="\n";
		print "has been written.\n";
	}

	$numLoop++;
	if((keys %h_assign_new) == 0 || $BCP_Parameter == 0){
		$isEnd = 1;
	}
	else{
		$str="";
	}
}

my $total_var = 0 ;
my $total_clause = 0 ;
my $total_literal = 0 ;
$total_var = $c_v_placement + $c_v_placement_aux + $c_v_routing + $c_v_routing_aux + $c_v_connect + $c_v_connect_aux + $c_v_dr;
$total_clause = $c_c_placement + $c_c_routing + $c_c_connect + $c_c_dr;
$total_literal = $c_l_placement + $c_l_routing + $c_l_connect +$c_l_dr;

print $out ";A. Variables for Routing\n";
foreach my $key(sort(keys %h_var)){
	print $out "(declare-const $key Bool)\n";
}
print $out $str;
foreach my $key(sort(keys %h_assign)){
	if($h_assign{$key} == 1){
		print $out "(assert (= $key true))\n";
	}
}
if($BCP_Parameter == 0){
	print $out ";WO BCP\n";
	foreach my $key(sort(keys %h_assign_new)){
		if($h_assign_new{$key} == 1){
			print $out "(assert (= $key true))\n";
		}
		else{
			print $out "(assert (= $key false))\n";
		}
	}
}

print "a   E. Check SAT & Optimization\n";
print $out ";E. Check SAT & Optimization\n";

print $out "(assert (bvsle COST_SIZE_P (_ bv$numTrackV ".(length(sprintf("%b", $numTrackV))+4).")))\n";
print $out "(assert (bvsle COST_SIZE_N (_ bv$numTrackV ".(length(sprintf("%b", $numTrackV))+4).")))\n";

for my $row (0 .. $numTrackH -3){
	print $out "(assert (= M2_TRACK_$row (or";
	my $len = length(sprintf("%b", $numTrackV))+4;
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1]; # 1:metal 2:row 3:col
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3]; # 1:metal 2:row 3:col
		my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
		my $toRow = (split /[a-z]/, $udEdges[$udeIndex][2])[2]; # 1:metal 2:row 3:col
		if($toMetal == 4 && ($fromRow == $row && $toRow == $row)){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";
			}
		}
	}
	print $out ")))\n";
}
foreach my $key(sort(keys %h_extnets)){
	my $netIndex = $h_idx{$key};
	for my $row (0 .. $numTrackH -3){
		my $tmp_str = "";
		my $cnt_var = 0;
		$tmp_str.="(assert (= N".$key."_M2_TRACK_$row (or";
		my $len = length(sprintf("%b", $numTrackV))+4;
		for my $udeIndex (0 .. $#udEdges) {
			my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
			my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1]; # 1:metal 2:row 3:col
			my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
			my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3]; # 1:metal 2:row 3:col
			my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
			my $toRow = (split /[a-z]/, $udEdges[$udeIndex][2])[2]; # 1:metal 2:row 3:col
			if($toMetal == 4 && ($fromRow == $row && $toRow == $row)){
				for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
					if(exists($h_var{"N$key\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						$tmp_str.=" N$key\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]";
						$cnt_var++;
					}
				}
			}
		}
		$tmp_str.=")))\n";
		if($cnt_var==0){
			$tmp_str="(assert (= N".$key."_M2_TRACK_$row false))\n";
		}
		print $out $tmp_str;
	}
	print $out "(assert (= N".$key."_M2_TRACK (or";
	for my $row (0 .. $numTrackH -3){
		print $out " N".$key."_M2_TRACK_$row";
	}
	print $out ")))\n";
}

my $isPRT_P = 0;
my $isPRT_N = 0;
if($Partition_Parameter == 1){
	my @arr_bound = ();
	for my $i (0 .. $lastIdxPMOS) {
		if(!exists($h_inst_group{$i})){
			push(@arr_bound, $i);
		}
	}
	my $numP = scalar @inst_group_p;
	if($numP > 0){
		my $numInstP = scalar @{$inst_group_p[0][1]};
		for my $j (0 .. $numInstP - 1){
			my $i = $inst_group_p[0][1][$j];
			push(@arr_bound, $i);
		}
	}

	my $numP = scalar @arr_bound;
	if($numP > 0){
		print $out "(assert (= COST_SIZE_P";
		for my $j (0 .. $numP - 2){
			print $out " (max";
		}
		my $i = $arr_bound[0];
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		my $len = length(sprintf("%b", $numTrackV))+4;
		my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
		my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
		print $out " (bvadd x$i $s_first)";
		for my $j (1 .. $numP-1){
			my $i = $arr_bound[$j];
			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
			my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
			print $out " (bvadd x$i $s_first))";
		}
		print $out "))\n";
		$isPRT_P = 1;
	}

	@arr_bound = ();
	for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
		if(!exists($h_inst_group{$i})){
			push(@arr_bound, $i);
		}
	}
	my $numN = scalar @inst_group_n;
	if($numN > 0){
		my $numInstN = scalar @{$inst_group_n[0][1]};
		for my $j (0 .. $numInstN - 1){
			my $i = $inst_group_n[0][1][$j];
			push(@arr_bound, $i);
		}
	}

	my $numN = scalar @arr_bound;
	if($numN > 0){
		print $out "(assert (= COST_SIZE_N";
		for my $j (0 .. $numN - 2){
			print $out " (max";
		}
		my $i = $arr_bound[0];
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		my $len = length(sprintf("%b", $numTrackV))+4;
		my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
		my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
		print $out " (bvadd x$i $s_first)";
		for my $j (1 .. $numN-1){
			my $i = $arr_bound[$j];
			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
			my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
			print $out " (bvadd x$i $s_first))";
		}
		print $out "))\n";
		$isPRT_N = 1;
	}
}
else{
	print $out "(assert (= COST_SIZE_P";
	for my $j (0 .. $lastIdxPMOS - 1){
		print $out " (max";
	}
	my $i = 0;
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	my $len = length(sprintf("%b", $numTrackV))+4;
	my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-$len2-1){
			$tmp_str.="0";
		}
	}
	my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
	print $out " (bvadd x$i $s_first)";
	for my $j (1 .. $lastIdxPMOS){
		my $i = $j;
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		my $len = length(sprintf("%b", $numTrackV))+4;
		my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
		my $tmp_str = "";
		if($len>1){
			for my $i(0 .. $len-$len2-1){
				$tmp_str.="0";
			}
		}
		my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
		print $out " (bvadd x$i $s_first))";
	}
	print $out "))\n";

	print $out "(assert (= COST_SIZE_N";
	for my $j ($lastIdxPMOS + 1 .. $numInstance - 2) {
		print $out " (max";
	}
	my $i = $lastIdxPMOS + 1;
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	my $len = length(sprintf("%b", $numTrackV))+4;
	my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-$len2-1){
			$tmp_str.="0";
		}
	}
	my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
	print $out " (bvadd x$i $s_first)";
	for my $j ($lastIdxPMOS + 2 .. $numInstance - 1) {
		my $i = $j;
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		my $len = length(sprintf("%b", $numTrackV))+4;
		my $len2 = length(sprintf("%b", 2*$tmp_finger[0]+1));
		my $tmp_str = "";
		if($len>1){
			for my $i(0 .. $len-$len2-1){
				$tmp_str.="0";
			}
		}
		my $s_first = "(_ bv".(2*$tmp_finger[0])." $len)";
		print $out " (bvadd x$i $s_first))";
	}
	print $out "))\n";
}


print $out "(assert (= COST_SIZE (max COST_SIZE_P COST_SIZE_N)))\n";

print $out "(minimize COST_SIZE)\n";

my $idx_obj = 0;
my $limit_obj = 150;

$idx_obj = 0;
$limit_obj = 10;
print $out "(minimize (bvadd";
for my $row (0 .. $numTrackH-3) {
	if($idx_obj >= $limit_obj){
		$idx_obj = 0;
		print $out "))\n";
		print $out "(minimize (bvadd";
	}
	print $out " (ite (= M2_TRACK_$row true) (_ bv1 ".(length(sprintf("%b", $numTrackH))).") (_ bv0 ".(length(sprintf("%b", $numTrackH)))."))";
	$idx_obj++;
}
print $out "))\n";

my $numTrackAssign = keys %h_net_track;
if($numTrackAssign>0){
	print $out "(minimize (bvadd";
	for my $netIndex (0 .. $#nets) {
		if(exists($h_net_track{$nets[$netIndex][1]})){
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $str_opt = "";
			for my $udeIndex (0 .. $#udEdges) {
				my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
				my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
				my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
				my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
				if($fromMetal != $toMetal && $toMetal == 4){
					if(exists($h_var{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						print $out " (ite (= N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
					}
				}
			}
		}
	}
	print $out "))\n";
	print $out "(minimize (bvadd";
	for my $netIndex (0 .. $#nets) {
		if(exists($h_net_track{$nets[$netIndex][1]})){
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $str_opt = "";
			for my $udeIndex (0 .. $#udEdges) {
				my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
				my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
				my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
				my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
				if($fromMetal != $toMetal && $toMetal == 3){
					if(exists($h_var{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						print $out " (ite (= N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
					}
				}
			}
		}
	}
	print $out "))\n";
	print $out "(minimize (bvadd";
	for my $netIndex (0 .. $#nets) {
		if(exists($h_net_track{$nets[$netIndex][1]})){
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $str_opt = "";
			for my $udeIndex (0 .. $#udEdges) {
				my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
				my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
				my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
				my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
				if($fromMetal != $toMetal && $toMetal == 2){
					if(exists($h_var{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						print $out " (ite (= N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
					}
				}
			}
		}
	}
	print $out "))\n";
	print $out "(minimize (bvadd";
	for my $netIndex (0 .. $#nets) {
		if(exists($h_net_track{$nets[$netIndex][1]})){
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $str_opt = "";
			for my $udeIndex (0 .. $#udEdges) {
				my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
				my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
				my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
				my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
				if($fromMetal == $toMetal && $toMetal == 2){
					if(exists($h_var{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						print $out " (ite (= N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
					}
				}
			}
		}
	}
	print $out "))\n";
	print $out "(minimize (bvadd";
	for my $netIndex (0 .. $#nets) {
		if(exists($h_net_track{$nets[$netIndex][1]})){
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $str_opt = "";
			for my $udeIndex (0 .. $#udEdges) {
				my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
				my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
				my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
				my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
				if($fromMetal == $toMetal && $toMetal == 3){
					if(exists($h_var{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						print $out " (ite (= N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
					}
				}
			}
		}
	}
	print $out "))\n";
	print $out "(minimize (bvadd";
	for my $netIndex (0 .. $#nets) {
		if(exists($h_net_track{$nets[$netIndex][1]})){
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $str_opt = "";
			for my $udeIndex (0 .. $#udEdges) {
				my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
				my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
				my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
				my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
				if($fromMetal == $toMetal && $toMetal == 4){
					if(exists($h_var{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
						print $out " (ite (= N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
					}
				}
			}
		}
	}
	print $out "))\n";
}

if($objpart_Parameter == 0){
	print $out "(minimize (bvadd";
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
		if($toMetal >= 2){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " (ite (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
				$idx_obj++;
			}
		}
	}
	print $out "))\n";
	$idx_obj = 0;
}
else{
	print $out "(minimize (bvadd";
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];

		if($fromMetal!=$toMetal && ($toMetal>=2 && $toMetal<=2)){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " (ite (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
				$idx_obj++;
			}
		}
	}
	print $out "))\n";
	$idx_obj = 0;

	print $out "(minimize (bvadd";
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];

		if($fromMetal!=$toMetal && ($toMetal>=3 && $toMetal<=3)){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " (ite (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
				$idx_obj++;
			}
		}
	}
	print $out "))\n";
	$idx_obj = 0;

	print $out "(minimize (bvadd";
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];

		if($fromMetal!=$toMetal && ($toMetal>=4 && $toMetal<=4)){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " (ite (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
				$idx_obj++;
			}
		}
	}
	print $out "))\n";
	$idx_obj = 0;

	print $out "(minimize (bvadd";
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];

		if($fromMetal==$toMetal && ($toMetal>=2 && $toMetal<=2)){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " (ite (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
				$idx_obj++;
			}
		}
	}
	print $out "))\n";
	$idx_obj = 0;

	print $out "(minimize (bvadd";
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];

		if($fromMetal==$toMetal && ($toMetal>=3 && $toMetal<=3)){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " (ite (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
				$idx_obj++;
			}
		}
	}
	print $out "))\n";
	$idx_obj = 0;

	print $out "(minimize (bvadd";
	for my $udeIndex (0 .. $#udEdges) {
		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
		my $toCol = (split /[a-z]/, $udEdges[$udeIndex][2])[3];

		if($fromMetal==$toMetal && ($toMetal>=4 && $toMetal<=4)){
			if(exists($h_var{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"})){
				print $out " (ite (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] true) (_ bv$udEdges[$udeIndex][3] 32) (_ bv0 32))";
				$idx_obj++;
			}
		}
	}
	print $out "))\n";
	$idx_obj = 0;
}
print $out "(check-sat)\n";
print $out "(get-model)\n";
print $out "(get-objectives)\n";
print "a   Total # Variables      = $total_var\n";
print "a   Total # Literals       = $total_literal\n";
print "a   Total # Clauses        = $total_clause\n";
print $out "; Total # Variables      = $total_var\n";
print $out "; Total # Literals       = $total_literal\n";
print $out "; Total # Clauses        = $total_clause\n";
close ($out);

print "a     ########## Summary ##########\n";
print "a     # var for placement       = $c_v_placement\n";
print "a     # var for placement(aux)  = $c_v_placement_aux\n";
print "a     # var for routing         = $c_v_routing\n";
print "a     # var for routing(aux)    = $c_v_routing_aux\n";
print "a     # var for design rule     = $c_v_dr\n";
print "a     # literals for placement   = $c_l_placement\n";
print "a     # literals for routing     = $c_l_routing\n";
print "a     # literals for design rule = $c_l_dr\n";
print "a     # clauses for placement   = $c_c_placement\n";
print "a     # clauses for routing     = $c_c_routing\n";
print "a     # clauses for design rule = $c_c_dr\n";
exit(-1);

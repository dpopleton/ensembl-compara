package Bio::EnsEMBL::Compara::Family;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
use IO::File;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

=head2 new

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : Bio::EnsEMBL::Compara::Family (but without members; caller has to fill using
               add_member)
  Exceptions : 
  Caller     : 

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
     #do this explicitly.
     my ($description_score) = $self->_rearrange([qw(DESCRIPTION_SCORE)], @args);
      
      $description_score && $self->description_score($description_score);
  }
  
  return $self;
}   

=head2 description_score

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub description_score {
  my $self = shift;
  $self->{'_description_score'} = shift if(@_);
  return $self->{'_description_score'};
}


=head2 read_clustalw

  Arg [1]    : string $file 
               The name of the file containing the clustalw output  
  Example    : $family->read_clustalw('/tmp/clustalw.aln');
  Description: Parses the output from clustalw and sets the alignment strings
               of each of the memebers of this family
  Returntype : none
  Exceptions : thrown if file cannot be parsed
               warning if alignment file contains identifiers for sequences
               which are not members of this family
  Caller     : general

=cut

sub read_clustalw {
  my $self = shift;
  my $file = shift;

  my %align_hash;
  my $FH = IO::File->new();
  $FH->open($file) || $self->throw("Could not open alignment file [$file]");

  <$FH>; #skip header
  while(<$FH>) {
    next if($_ =~ /^\s+/);  #skip lines that start with space
    
    my ($id, $align) = split;
    $align_hash{$id} ||= '';
    $align_hash{$id} .= $align;
  }

  $FH->close;

  #place all member attributes in a hash on their member name
  my %attribute_hash;
  foreach my $member_attribute (@{$self->get_all_Member}) {
    my ($member, $attribute) = @{$member_attribute};
    $attribute_hash{$member->stable_id} = $attribute;
  }

  #assign cigar_line to each of the member attribute
  foreach my $id (keys %align_hash) {
    my $attribute = $attribute_hash{$id};
    if($attribute) {
      my $alignment_string = $align_hash{$id};
      $alignment_string =~ s/\-([A-Z])/\- $1/g;
      $alignment_string =~ s/([A-Z])\-/$1 \-/g;

      my @cigar_segments = split " ",$alignment_string;

      my $cigar_line = "";
      foreach my $segment (@cigar_segments) {
        my $seglength = length($segment);
        $seglength = "" if ($seglength == 1);
        if ($segment =~ /^\-+$/) {
          $cigar_line .= $seglength . "D";
        } else {
          $cigar_line .= $seglength . "M";
        }
      }

      $attribute->cigar_line($cigar_line);

    } else {
      $self->warn("No member for alignment portion: [$id]");
    }
  }
}

sub get_SimpleAlign {
  my $self = shift;

  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  if(!$sa->can('add_seq')) {
    $bio07 = 1;
  }

  foreach my $member_attribute (@{$self->get_all_Member}) {
    my ($member, $attribute) = @{$member_attribute};
    my $seqstr = $attribute->alignment_string($member);
    next if(!$seqstr);
    my $seq = Bio::LocatableSeq->new(-SEQ    => $seqstr,
                                     -START  => 1,
                                     -END    => length($seqstr),
                                     -ID     => $member->stable_id,
                                     -STRAND => 0);

    if($bio07) {
      $sa->addSeq($seq);
    } else {
      $sa->add_seq($seq);
    }
  }

  return $sa;
}

1;

cd ../generated/perl/HaikuKits
cd $1
rm $1.c
perl Makefile.PL
cd ..
make

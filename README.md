# A mail-merge tool for Mac OS X

This is a tool that I use to send out personalised emails _en masse_, e.g. giving marks and feedback to a class of students. I'm making it available in case it is useful for others too.

## Requirements

- Mac OS X (tested on Ventura 13.0.1)
- OCaml (tested on version 4.13.1)
- Apple Mail
- Apple Numbers

## Assumptions

I assume you have a CSV file generated from an Apple Numbers spreadsheet. I mention Apple Numbers because CSV is a surprisingly unstandardised format, and my tool is quite specialised for the dialect of CSV that Apple Numbers exports. Other CSV files might or might not work. In particular:

- values are comma-separated (as you would expect),
	
- values that do (or could) contain commas or newlines are wrapped in double-quotes,
	
- but empty values are not wrapped in double-quotes,
	
- double-quotes that appear inside values are replaced with two consecutive double-quotes (so "this is an ""example"" of a valid value")
	
I assume that at least one of the columns in your CSV file has a name that begins with "email". This column contains the recipients of your emails. If you have multiple such columns (e.g. "email 1" and "email 2") then your emails will have multiple recipients.

I assume that you have a "template" file. This is an ordinary text file that can contain placeholders that will be instantiated with data from the CSV file. For instance, if you write `${firstname}` in the template file, it will be replaced with data from the column called "firstname" in your CSV file. (If such a column doesn't exist, no replacement will occur.)

## Getting started

Run `make`.

This repo includes a sample template file and a sample CSV file. To use them to see how the tool works, run the following command:

    ./mailer -template template.txt -csv database.csv -subject "Results" -cc "b.jones@gmail.com"

You can also run `make install` to copy the executable into `~/bin`. Then, if `~/bin` is in your `$PATH`, you can run `csv_iterator` from any directory.

## What the tool does
		
1. The tool creates a new file called `database.csv.tmp` in which `""` has been globally replaced with `` ` ``. This makes a Numbers-generated CSV file easier to parse (see note above).
 
2. The tool creates a directory called `out-YYYYMMDD-hhmmss` to contain the Applescripts that it is about to generate. The use of a timestamp means that you don't have to think about where you want to put the output from each run of the tool.
 
3. The tool creates one Applescript per row of `database.csv.tmp`. Each Applescript is generated such that when it is executed, a new email will be created in Apple Mail, all populated according to `template.txt` and instantiated with the data in the current row. The email won't actually be sent, but it will be all ready for you to just click on "send".
 
4. The tool will, by default, execute all the Applescripts it generates. Alternatively, you can set the `-dryrun` flag so that they are not executed, and instead execute the scripts later yourself, e.g. by running `osascript name_of_script.scpt`.

5. The tool will, by default, process all the rows in the CSV file, but if you add `-onlyfirst <N>` flag, it will stop after the first `N` (non-header) rows. This can be useful when testing.

6. If you add `-attach <column name>` then the given column name will be interpreted as holding paths to files that should be attached to the emails. These should be full file paths, with colons as directory separators, such as "Macintosh HD:Users:jpw48:teaching:comments_smith.txt".

There are additional command-line options to configure the sender's name and email address, and to add recipients in cc or bcc.

## Feature wishlist

- Conditionals in template files. E.g. only include a piece of text if a specified column contains "true".

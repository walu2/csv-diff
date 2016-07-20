GEMSPEC = Gem::Specification.new do |s|
    s.name = "csv-diff"
    s.version = "0.3.2"
    s.authors = ["Adam Gardiner", "Piotr Walkowski"]
    s.date = "2016-07-20"
    s.summary = "CSV Diff is a library for generating diffs from data in CSV format"
    s.description = <<-EOQ
        This library performs diffs of CSV files.

        Unlike a standard diff that compares line by line, and is sensitive to the
        ordering of records, CSV-Diff identifies common lines by key field(s), and
        then compares the contents of the fields in each line.

        Data may be supplied in the form of CSV files, or as an array of arrays. The
        diff process provides a fine level of control over what to diff, and can
        optionally ignore certain types of changes (e.g. changes in position).

        CSV-Diff is particularly well suited to data in parent-child format. Parent-
        child data does not lend itself well to standard text diffs, as small changes
        in the organisation of the tree at an upper level can lead to big movements
        in the position of descendant records. By instead matching records by key,
        CSV-Diff avoids this issue, while still being able to detect changes in
        sibling order.

        This gem implements the core diff algorithm, and handles the loading and
        diffing of CSV files. It returns a CSVDiff object, that contains the details
        of differences in object form. This is useful for projects that need diff
        capability, but want to handle the reporting of differences themselves. For
        a pre-built diff reporting capability, see the csv-diff-report gem, which
        provides a command-line tool for generating diff reports in HTML or Excel
        format.
    EOQ
    s.email = "piotr@deluxe-soft.com"
    s.homepage = 'https://github.com/walu2/csv-diff'
    s.require_paths = ['lib']
    s.files = ['README.md', 'LICENSE'] + Dir['lib/**/*.rb']
    s.licenses = 'MIT'
    s.post_install_message = "For command-line tools and diff reports, 'gem install csv-diff-report'"
end

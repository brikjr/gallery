#!/bin/bash

echo "Cleaning up unnecessary files..."

# Remove directories
rm -rf newsletter/
rm -rf journal/
rm -rf _posts/
rm -rf about/
rm -rf .vscode/

# Remove JavaScript files
rm js/jquery.cycle.min.js
rm js/jquery.lazylinepainter.min.js
rm js/jquery.mousewheel.min.js
rm js/jquery.tinycarousel.min.js

# Remove configuration files
rm bower.json
rm Gruntfile.js
rm package.json
rm config.gemspec

# Remove unused includes and layouts
rm _includes/disqus_comments.html
rm _includes/signoff.html
rm _includes/share.html
rm _includes/footer.html
rm _layouts/journal_by_category.html
rm _layouts/journal_by_tag.html
rm _layouts/home.html

# Remove other files
rm feed.xml
rm search.json
rm search.html
rm css/journal.css

echo "Cleanup complete!"

# Optional: Git commands to commit changes
read -p "Would you like to commit these changes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    git add -A
    git commit -m "Cleanup: Remove unnecessary files"
    echo "Changes committed!"
fi 
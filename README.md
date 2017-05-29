# pgsql-mbox-download
 This is a download script for [PostgreSQL Mailing Lists](https://www.postgresql.org/list/).
 
 On first run it downloads all mailing lists. On subsequent runs it downloads only new and changed mbox files.
 
 ## Usage
 
 * Build the Docker image
   ```bash
   sudo ./build.sh
   ```
 * Run the Docker container by specifying the download directory.
   ```bash
   sudo ./run.sh ~/Downloads/pgsql-mbox-files/
   ```

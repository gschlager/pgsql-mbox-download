FROM ruby:3

RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY ./src /usr/src/app

RUN mkdir /data

CMD ["ruby", "./download_pgsql_lists.rb"]

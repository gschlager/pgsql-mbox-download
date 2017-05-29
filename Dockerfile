FROM ruby:2.4

RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY ./src /usr/src/app
RUN bundle install

RUN mkdir /data

CMD ["ruby", "./download_pgsql_lists.rb"]

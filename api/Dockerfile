FROM ruby:3.3-slim AS base
RUN apt-get update -qq && \
    apt-get install -y libpq-dev libjemalloc2 curl libvips && \
    rm -rf /var/lib/apt/lists/*
ENV LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1
ENV MALLOC_ARENA_MAX=2
WORKDIR /app

FROM base AS build
RUN apt-get update -qq && \
    apt-get install -y build-essential git && \
    rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test && \
    rm -rf ~/.bundle/ /usr/local/bundle/cache
COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/

FROM base
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

EXPOSE 8080
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

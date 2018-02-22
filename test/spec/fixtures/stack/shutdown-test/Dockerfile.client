FROM alpine

RUN apk update && apk --update add ruby

ADD client.rb .

CMD ["ruby", "client.rb"]

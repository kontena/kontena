FROM alpine

RUN apk update && apk --update add ruby 

ADD server.rb .

CMD ["ruby", "server.rb"]

FROM node:16-alpine

WORKDIR /app

RUN npm install -g yarn

COPY package*.json ./

RUN yarn install

COPY . .

CMD ["node", "index.js"]
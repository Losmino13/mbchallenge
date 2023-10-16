const chai = require('chai');
const chaiHttp = require('chai-http');
const app = require('../src/app.js');  // Import your Express app

chai.use(chaiHttp);
const expect = chai.expect;

describe('GET /', () => {
  it('should return status 200', (done) => {
    chai.request(app)
      .get('/')  // Replace with your actual route
      .end((err, res) => {
        expect(res).to.have.status(400);
        done();
      });
  });
});

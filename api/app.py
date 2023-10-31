from flask import Flask, request

app = Flask(__name__)


@app.route('/')
def hello_world():
    input1 = request.args.get('input1')
    input2 = request.args.get('input2')
    input3 = request.args.get('input3')
    return 'Hello World! {} {} {}'.format(input1, input2, input3)


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
from flask import Flask, render_template

app = Flask(__name__)

@app.route('/')
def signup_page():
    return render_template('signup.html')

@app.route('/login')
def login_page():
    return render_template('login.html')

@app.route('/forgot_password')
def forgot_password_page():
    return render_template('forgot_password.html')

@app.route('/home')
def home_page():
    return render_template('home.html')

@app.route('/messages')
def messages_page():
    return render_template('messages.html')

@app.route('/profile')
def profile_page():
    return render_template('profile.html')

if __name__ == '__main__':
    app.run(debug=True)
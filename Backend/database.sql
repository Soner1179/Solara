-- Create Users table
CREATE TABLE public.Users (
    user_id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Düzeltildi
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP   -- Düzeltildi
);

-- Create Posts table
CREATE TABLE public.Posts (
    post_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Düzeltildi
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Düzeltildi
    FOREIGN KEY (user_id) REFERENCES public.Users(user_id) -- Şema adı eklendi (iyi pratik)
);

-- Create Chats table
CREATE TABLE public.Chats (
    chat_id SERIAL PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Düzeltildi
);

-- Create Messages table
CREATE TABLE public.Messages (
    message_id SERIAL PRIMARY KEY,
    chat_id INTEGER NOT NULL,
    sender_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Düzeltildi
    FOREIGN KEY (chat_id) REFERENCES public.Chats(chat_id),     -- Şema adı eklendi
    FOREIGN KEY (sender_id) REFERENCES public.Users(user_id)   -- Şema adı eklendi
);

-- Create Comments table
CREATE TABLE public.Comments (
    comment_id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES public.Posts(post_id),
    FOREIGN KEY (user_id) REFERENCES public.Users(user_id)
);

-- Create Likes table
CREATE TABLE public.Likes (
    like_id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES public.Posts(post_id),
    FOREIGN KEY (user_id) REFERENCES public.Users(user_id),
    UNIQUE (post_id, user_id) -- Ensure a user can only like a post once
);

-- Create Followers table
CREATE TABLE public.Followers (
    follower_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL, -- The user being followed
    follower_user_id INTEGER NOT NULL, -- The user who is following
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES public.Users(user_id),
    FOREIGN KEY (follower_user_id) REFERENCES public.Users(user_id),
    UNIQUE (user_id, follower_user_id) -- Ensure a user can only follow another user once
);

-- Create SavedPosts table
CREATE TABLE public.SavedPosts (
    saved_post_id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES public.Posts(post_id),
    FOREIGN KEY (user_id) REFERENCES public.Users(user_id),
    UNIQUE (post_id, user_id) -- Ensure a user can only save a post once
);

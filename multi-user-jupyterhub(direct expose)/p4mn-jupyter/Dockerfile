# Use the official Jupyter Notebook base image
FROM jupyter/base-notebook:latest

# Switch to root user to install system dependencies
USER root

# Update the package list and install Mininet dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    make \
    python3-dev \
    net-tools \
    iproute2 \
    iputils-ping \
    ethtool \
    vim \
    wget \
    curl \
    sudo \
    lsb-release \
    openssh-client \  
    psmisc \          
    socat \           
    xterm \           
    iperf \           
    telnet \          
    help2man \        
    pyflakes3 \       
    pylint \          
    pep8 \            
    python3-pip \     
    cgroup-tools \    
    && rm -rf /var/lib/apt/lists/*

# Install Mininet from source
RUN git clone https://github.com/mininet/mininet.git /tmp/mininet && \
    cd /tmp/mininet && \
    make install && \
    rm -rf /tmp/mininet

RUN git clone https://github.com/jafingerhut/p4-guide
RUN ./p4-guide/bin/install-p4dev-v8.sh |& tee log.txt


ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH


# Add LD_LIBRARY_PATH to sudoers
RUN echo 'Defaults env_keep += "LD_LIBRARY_PATH"' | tee -a /etc/sudoers

RUN ldconfig

# Add jovyan user to sudoers (passwordless sudo)
RUN echo "Defaults secure_path=\"/opt/conda/bin:/opt/conda/condabin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" >> /etc/sudoers
RUN echo "jovyan ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

#Install P4RuntimeShell

#Install bash 
RUN pip install bash_kernel

#Alias
#RUN alias connect='python3 -m p4runtime_sh'

RUN apt-get install nano

# Switch back to the jovyan user (default user in Jupyter images)
USER $NB_UID

# Define an alias
#RUN echo 'alias connect="python3 -m p4runtime_sh"' >> ~/.bashrc
# Ensure the alias is available in non-interactive shells
#RUN echo 'source ~/.bashrc' >> ~/.bash_profile
RUN echo 'source ${HOME}/p4setup.bash' >> ${HOME}/.bashrc 
RUN echo 'export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python' >> ${HOME}/.bashrc

#Alias
#RUN alias connect='python3 -m p4runtime_sh'

# Set the working directory
WORKDIR /home/jovyan/work

#

RUN git clone https://github.com/p4lang/tutorials.git

COPY ./data . 
# Expose the Jupyter Notebook port (default is 8888)
EXPOSE 8888

# Start the Jupyter Notebook server
#CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--no-browser", "--allow-root"]

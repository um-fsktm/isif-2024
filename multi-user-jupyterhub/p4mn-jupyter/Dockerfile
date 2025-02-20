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

# Install Python dependencies for P4 and Mininet
RUN pip install --no-cache-dir \
    ipython \
    networkx \
    matplotlib \
    scapy \
    thrift \
    grpcio \
    p4runtime

#Install bmv2
#RUN . /etc/os-release && \
#    echo "deb http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/home:p4lang.list && \
#    curl -fsSL "https://download.opensuse.org/repositories/home:p4lang/xUbuntu_${VERSION_ID}/Release.key" | gpg --dearmor | tee /etc/apt/trusted.gpg.d/home_p4lang.gpg > /dev/null && \
#    apt-get update

#RUN apt-get install -y p4lang-bmv2

#Installing simple_switch_grpc

RUN apt-get update && apt-get install -y autoconf automake libtool && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y pkg-config libprotobuf-dev protobuf-compiler && rm -rf /var/lib/apt/lists/*

# Install gRPC and its dependencies
RUN apt-get update && apt-get install -y \
    libgrpc-dev \  
    libgrpc++-dev \  
    protobuf-compiler-grpc \  
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    git \
    wget \
    build-essential \
    cmake \
    libboost-dev \  
    libboost-system-dev \  
    libboost-thread-dev \  
    libboost-program-options-dev \  
    libboost-filesystem-dev \  
    libboost-iostreams-dev \  
    libevent-dev \
    libtool \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root
RUN git clone https://github.com/p4lang/PI.git
WORKDIR /root/PI
RUN git submodule update --init --recursive
RUN ./autogen.sh
RUN ./configure --with-proto --without-internal-rpc --without-cli --without-bmv2
RUN make
RUN make install


RUN apt-get update && apt-get install -y libgmp-dev libpcap-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /root
RUN git clone https://github.com/p4lang/behavioral-model.git
WORKDIR /root/behavioral-model
RUN ./autogen.sh
RUN ./configure --with-pi --without-thrift --without-nanomsg
RUN make
RUN make install

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH


# Add LD_LIBRARY_PATH to sudoers
RUN echo 'Defaults env_keep += "LD_LIBRARY_PATH"' | tee -a /etc/sudoers

RUN ldconfig

# Add jovyan user to sudoers (passwordless sudo)
RUN echo "Defaults secure_path=\"/opt/conda/bin:/opt/conda/condabin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" >> /etc/sudoers
RUN echo "jovyan ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

#Install P4RuntimeShell
RUN pip3 install p4runtime-shell

#Install bash 
RUN pip install bash_kernel

#Alias
#RUN alias connect='python3 -m p4runtime_sh'

# Switch back to the jovyan user (default user in Jupyter images)
USER $NB_UID

# Define an alias
RUN echo 'alias connect="python3 -m p4runtime_sh"' >> ~/.bashrc
# Ensure the alias is available in non-interactive shells
RUN echo 'source ~/.bashrc' >> ~/.bash_profile

#Alias
#RUN alias connect='python3 -m p4runtime_sh'

# Set the working directory
WORKDIR /home/jovyan/work

COPY ./data . 
# Expose the Jupyter Notebook port (default is 8888)
EXPOSE 8888

# Start the Jupyter Notebook server
#CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--no-browser", "--allow-root"]

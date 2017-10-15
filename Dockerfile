FROM ubuntu:16.04
MAINTAINER Caleb Kemere <caleb.kemere@rice.edu>

RUN apt-get update && apt-get -yq dist-upgrade
RUN apt-get update -yqq &&  \
    apt-get install -yqq bzip2 git wget \
              vim ca-certificates sudo locales fonts-liberation \
              libgl1-mesa-glx \
              pkg-config graphviz build-essential gcc python && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Install Tini that necessary to properly run the notebook service in docker
# http://jupyter-notebook.readthedocs.org/en/latest/public_server.html#docker-cmd
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini

# for further interaction with kubernetes
ADD https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kubectl /usr/sbin/kubectl
RUN chmod +x /usr/bin/tini && chmod 0500 /usr/sbin/kubectl

# Create a non-priviledge user that will run the client and workers
ENV BASICUSER basicuser
ENV BASICUSER_UID 1000
RUN useradd -m -d /work -s /bin/bash -N -u $BASICUSER_UID $BASICUSER 
# RUN useradd -m -d /work -s /bin/bash -N -u $BASICUSER_UID $BASICUSER \
 # && chown $BASICUSER /work \
 # && chown $BASICUSER:users -R /work

# Install Python 3 from miniconda
ADD https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh miniconda.sh
RUN chown $BASICUSER:users miniconda.sh

USER $BASICUSER

# Configure environment
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8


RUN mkdir -p /work/bin

# Install Python 3 from miniconda - run as BASICUSER to get permissions right
RUN bash miniconda.sh -b -p /work/miniconda
USER root 
RUN rm miniconda.sh
USER $BASICUSER

# keep conda in user dir, so can do conda install in notebook
ENV PATH="/work/bin:/work/miniconda/bin:$PATH"

# Install pydata stack
RUN conda config --set always_yes yes --set changeps1 no --set auto_update_conda no
RUN conda install notebook psutil numpy pandas scikit-learn statsmodels pip numba \
        scikit-image datashader holoviews nomkl matplotlib lz4 tornado joblib graphviz
RUN conda install -c conda-forge fastparquet s3fs zict python-blosc cytoolz dask distributed dask-searchcv gcsfs \
 && conda clean -tipsy \
 && pip install git+https://github.com/dask/dask-glm.git --no-deps

RUN conda install -c conda-forge nodejs
RUN conda install -c conda-forge jupyterlab jupyter_dashboards ipywidgets \
 && jupyter labextension install @jupyter-widgets/jupyterlab-manager \
 && jupyter nbextension enable jupyter_dashboards --py --sys-prefix \
 && conda clean -tipsy

RUN conda install -c bokeh bokeh \
 && jupyter labextension install jupyterlab_bokeh \
 && conda clean -tipsy

RUN npm cache clean

# Optional: Install the master branch of distributed and dask
RUN pip install git+https://github.com/dask/dask --upgrade --no-deps
RUN pip install git+https://github.com/dask/distributed --upgrade --no-deps

# Nelpy-specific (make sure to install develop branch!)
RUN pip install git+https://github.com/eackermann/hmmlearn
RUN pip install git+https://github.com/nelpy/nelpy@develop

# Add local files at the end of the Dockerfile to limit cache busting
COPY config /work/config
COPY examples /work/examples
ENTRYPOINT ["/usr/bin/tini", "--"]


